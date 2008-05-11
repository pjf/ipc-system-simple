package IPC::System::Simple;

use 5.006;
use strict;
use warnings;
use re 'taint';
use Carp;
use List::Util qw(first);
use Scalar::Util qw(tainted);
use Config;
use constant WINDOWS => ($^O eq 'MSWin32');
use constant VMS     => ($^O eq 'VMS');
use if WINDOWS, 'Win32::Process', qw(INFINITE NORMAL_PRIORITY_CLASS);
use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

use constant FAIL_START => q{"%s" failed to start: "%s"};

# On Perl's older than 5.8.x we can't assume that there'll be a
# $^{TAINT} for us to check, so we assume that our args may always
# be tainted.
use constant ASSUME_TAINTED => ($] < 5.008);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( capture run $EXITVAL );
our $VERSION = '0.09';
our $EXITVAL = -1;

my @Signal_from_number = split(' ', $Config{sig_name});

# Environment variables we don't want to see tainted.
my @Check_tainted_env = qw(PATH IFS CDPATH ENV BASH_ENV);
if (WINDOWS) {
	push(@Check_tainted_env, 'PERL5SHELL');
}
if (VMS) {
	push(@Check_tainted_env, 'DCL$PATH');
}

# Not all systems implment the WIFEXITED calls, but POSIX
# will always export them (even if they're just stubs that
# die with an error).  Test for the presence of a working
# WIFEXITED and friends, or define our own.

eval { WIFEXITED(0); };

if ($@ =~ /not (?:defined|a valid) POSIX macro/) {
	*WIFEXITED   = sub { not $_[0] & 0xff };
	*WEXITSTATUS = sub { $_[0] >> 8  };
	*WIFSIGNALED = sub { $_[0] & 127 };
	*WTERMSIG    = sub { $_[0] & 127 };
} elsif ($@) {
	croak "IPC::System::Simple does not understand the POSIX error '$@'.  Please check http://search.cpan.org/perldoc?IPC::System::Simple to see if there is an updated version.  If not please report this as a bug to http://rt.cpan.org/Public/Bug/Report.html?Queue=IPC-System-Simple";
}

# TODO - This doesn't look for core-dumps yet.
# TODO - WTF is a WIFSTOPPED and how can it hurt us?

sub run {

	_check_taint(@_);

	my ($valid_returns, $command, @args) = _process_args(@_);

	# With the wonders of constant folding the following code
	# is completely optimised away under non-windows systems.

	# The following essentially emulates multi-argument system,
	# bypassing the shell entirely.

	if (WINDOWS and @args) {
		our $EXITVAL = -1;
		my $pid;

		# Using $flags in our anonymous sub below helps
		# avoid some compile-time hitches on non-Win32
		# systems.
		
		my $flags = NORMAL_PRIORITY_CLASS;

		# $spawn allows us to spawn a win32 process without
		# retyping all the awkward syntax each time.

		my $spawn = sub {
			return Win32::Process::Create(
				$pid, @_[0,1], 1, $flags, "."
			)
		};

		LAUNCH: {
			$spawn->($command, "$command @args") and last LAUNCH;

			# We may have failed simply because we haven't
			# got a full path to our executable.
			# Let's go looking for it.

			my @path = split(/;/,$ENV{PATH});

			foreach my $dir (@path) {
				my $fullpath = "$dir\\$command";
				if (-x $fullpath) {
					$spawn->($fullpath,"$command @args")
						and last LAUNCH;

				}
			}

			# If we're here, then we couldn't launch our
			# process, even if we tried to walk the path.

			croak sprintf(FAIL_START, $command, $^E);
		}


		$pid->Wait(INFINITE);	# Wait for process exit.
		$pid->GetExitCode($EXITVAL);
		return _check_exit($command,$EXITVAL,$valid_returns);
	}

	# On non-Win32 systems, or when we don't have multiple argument,
	# we have an easier time.

	# We're throwing our own exception on command not found, so
	# we don't need a warning from Perl.
	no warnings 'exec';
	system($command,@args);

	return _process_child_error($?,$command,$valid_returns);
}

sub capture {
	_check_taint(@_);

	my ($valid_returns, $command, @args) = _process_args(@_);

	our $EXITVAL = -1;

	my $wantarray = wantarray();

	if (WINDOWS) {
		# Perl doesn't support multi-arg backticks under
		# Windows.  Perl also doesn't provide very good
		# feedback when normal backtails fail, either,
		# instead returning the exit status from the shell
		# (which is indistinguishable from the command
		# running and producing the same exit status).

		# As such, we essentially have to write our own
		# backticks.

		# We start by dup'ing STDOUT.
		# XXX - Fix our diagnostics.
		# XXX - Flush buffers first?

		open(my $saved_stdout, '>&', \*STDOUT)
			or die "Internal error: Can't dup STDOUT";

		# We now open up a pipe that will allow us to	
		# communicate with the new process.

		# XXX - Fix our diagnostics.
		pipe(my ($read_fh, $write_fh))
			or die "Internal error: Can't open pipe";

		# Allow CRLF sequences to become "\n", since
		# I believe this is what Perl backticks do.
		# XXX - Is this a good idea?

		binmode($read_fh, ':crlf');

		# Now we re-open our STDOUT to $write_fh...
		open(STDOUT, '>&', $write_fh);

		# And now we spawn our new process with inherited
		# filehandles.

		# XXX - Search PATH properly.
		# XXX - Format diagnostics properly.

		my $exe = @args                      ? $command :
			  $command =~ m{^"([^"]+)"}x ? $1       :
			  $command =~ m{(\S+)     }x ? $1       :
			  croak("Cannot find command in $command");

		Win32::Process::Create(
			my $pid, $exe, "$command @args", 1, NORMAL_PRIORITY_CLASS, "."
		) or croak(sprintf FAIL_START,"$command",$^E);

		# Now restore our STDOUT.
		open(STDOUT, '>&', $saved_stdout)
			or die "Internal error: Can't restore STDOUT";

		# Clean-up the filehandles we no longer need...

		close($write_fh);
		close($saved_stdout);

		# Read the data from our child...

		my (@results, $result);

		if ($wantarray) {
			@results = <$read_fh>;
		} else {
			$result = join("",<$read_fh>);
		}

		# Tidy up our windows process and we're done!

		$pid->Wait(INFINITE);	# Wait for process exit.
		$pid->GetExitCode($EXITVAL);

		_check_exit($command,$EXITVAL,$valid_returns);

		return $wantarray ? @results : $result;
	}

	if (WINDOWS and @args) {
		croak "capture under Win32 unimplemented";
	}

	# We'll produce our own warnings on failure to execute.
	no warnings 'exec';

	if (not @args) {
		if ($wantarray) {
			my @results = qx($command);
			_process_child_error($?,$command,$valid_returns);
			return @results;
		} 

		my $results = qx($command);
		_process_child_error($?,$command,$valid_returns);
		return $results;
	}

	# If we're here, we have arguments.  Avoid the shell using
	# multi-arg open.

	# NB: We don't check the return status on close(), since
	# on failure it sets $?, which we then inspect for more
	# useful information.

	open(my $pipe, "-|", $command, @args)
		or croak sprintf(FAIL_START, $command, $!);

	if ($wantarray) {
		my @results = <$pipe>;
		close($pipe);
		_process_child_error($?,$command,$valid_returns);
		return @results;
	}

	my $results = join("",<$pipe>);
	close($pipe);
	_process_child_error($?,$command,$valid_returns);
	
	return $results;

}

# Complain on tainted arguments or environment.
# ASSUME_TAINTED is true for 5.6.x, since it's missing ${^TAINT}

sub _check_taint {
	return if not (ASSUME_TAINTED or ${^TAINT});
	foreach my $var (@_) {
		if (tainted $var) {
			croak qq{IPC::System::Simple::run called with tainted argument '$var'};
		}
	}
	foreach my $var (@Check_tainted_env) {
		if (tainted $ENV{$var} ) {
			croak qq{IPC::System::Simple::run called with tainted environment \$ENV{$var}};
		}
	}

	return;

}

# This subroutine performs the difficult task of interpreting
# $?.  It's not intended to be called directly, as it will
# croak on errors, and its implementation and interface may
# change in the future.

sub _process_child_error {
	my ($child_error, $command, $valid_returns) = @_;
	
	$EXITVAL = -1;

	if ($child_error == -1) {
		croak sprintf(FAIL_START, $command, $!);

	} elsif ( WIFEXITED( $child_error ) ) {
		$EXITVAL = WEXITSTATUS( $child_error );

		return _check_exit($command,$EXITVAL,$valid_returns);

	} elsif ( WIFSIGNALED( $child_error ) ) {
		my $signal_no   = WTERMSIG( $child_error );
		my $signal_name = $Signal_from_number[$signal_no] || "UNKNOWN";

		croak qq{"$command" died to signal "$signal_name" ($signal_no)};

	} 

	croak qq{Internal error in IPC::System::Simple - "$command" ran without exit value or signal};

}

# A simple subroutine for checking exit values.  Results in better
# assurance of consistent error messages, and better forward support
# for new features in I::S::S.

sub _check_exit {
	my ($command,$exitval, $valid_returns) = @_;
	if (not defined first { $_ == $exitval } @$valid_returns) {
		croak qq{"$command" unexpectedly returned exit value $exitval};
	}	
	return $exitval;
}


# This subroutine simply determines a list of valid returns, the command
# name, and any arguments that we need to pass to it.

sub _process_args {
	my $valid_returns = [ 0 ];
	my $caller = (caller(1))[3];

	if (not @_) {
		croak "IPC::System::Simple::$caller called with no arguments";
	}

	if (ref $_[0] eq "ARRAY") {
		$valid_returns = shift(@_);
	}

	if (not @_) {
		croak "IPC::System::Simple::$caller called with no command";
	}

	my $command = shift(@_);

	return ($valid_returns,$command,@_);

}

1;

__END__

=head1 NAME

IPC::System::Simple - Call system() commands with a minimum of fuss

=head1 SYNOPSIS

  use IPC::System::Simple qw(capture run $EXITVAL);

  # Run a command, throwing exception on failure

  run("some_command");

  run("some_command",@args);  # Run a command, avoiding the shell

  # Run a command which must return 0..5, avoid the shell, and get the
  # exit value (we could also look at $EXITVAL)

  my $exit_value = run([0..5], "some_command", @args);

  # Run a command, capture output into $result and throw exception on failure

  my $result = capture("some_command");	

  # Check exit value from captured command

  print "some_command exited with status $EXITVAL\n";

  my @lines = capture("some_command"); # Captures into @lines, splitting on $/

  # Run a command which must return 0..5, capture the output into
  # @lines, and avoid the shell.

  my @lines  = capture([0..5], "some_command", @args);

=head1 DESCRIPTION

Calling Perl's in-built C<system()> function is easy, but checking
the results can be hard.  C<IPC::System::Simple> aims to make
life easy for the I<common cases> of calling C<system> and
backticks (aka C<qx()>).

=head2 run

C<IPC::System::Simple> provides a subroutine called
C<run>, that executes a command using the same semantics is
Perl's built-in C<system>:

	use IPC::System::Simple qw(run);

	run("cat *.txt");		# Execute command via the shell
	run("cat","/etc/motd");		# Execute command without shell

=head2 capture

A second subroutine, named C<capture> executes a command with
the same semantics as Perl's built-in backticks (and C<qx()>):

	use IPC::System::Simple qw(capture);

	my $file  = capture("cat /etc/motd");
	my @lines = capture("cat /etc/passwd");

However unlike regular backticks, which always use the shell, C<capture>
will bypass the shell when called with multiple arguments:

	my $file  = capture("cat", "/etc/motd");
	my @lines = capture("cat", "/etc/passwd");

=head2 Exception handling

In the case where the command returns an unexpected status, both C<run> and
C<capture> will throw an exception, which if not caught will terminate your
program with an error.

Capturing the exception is easy:

	eval {
		run("cat *.txt");
	};

	if ($@) {
		print "Something went wrong - $@\n";
	}

See the diagnostics section below for more details.

=head3 Exception cases

C<IPC::System::Simple> considers the following to be unexpected,
and worthy of exception:

=over 4

=item *

Failing to start entirely (eg, command not found, permission denied).

=item *

Returning an exit value other than zero (but see below).

=item *

Being killed by a signal.

=item *

Being passed tainted data (in taint mode).

=back

=head2 Exit values

Traditionally, system commands return a zero status for success and a
non-zero status for failure.  C<IPC::System::Simple> will default to throwing
an exception if a non-zero exit value is returned.

You may specify a range of values which are considered acceptable exit
values by passing an I<array reference> as the first argument:

	run( [0..5], "cat *.txt");                   # Exit values 0-5 are OK

	my @lines = capture( [0..255], "cat *.txt"); # Any exit value is OK

The C<run> subroutine returns the exit value of the process:

	my $exit_value = run( [0..5], "cat *.txt");

	print "Program exited with value $exit_value\n";

=head3 $EXITVAL

The exit value of a command executed with either C<run> or
C<capture> can always be retrieved from the 
C<$IPC::System::Simple::EXITVAL> variable:

	use IPC::System::Simple qw(capture $EXITVAL);

	my @lines = capture("cat", "/etc/passwd");

	print "Program exited with value $EXITVAL\n";

This is particularly useful when inspecting results from C<capture>,
which returns the captured text from the command.

C<$EXITVAL> will be set to C<-1> if the command did not exit normally (eg,
being terminated by a signal) or did not start.

=head2 WINDOWS-SPECIFIC NOTES

As of C<IPC::System::Simple> v0.06, the C<run> subroutine I<when
called with multiple arguments> will make available the full 16-bit
return value on Win32 systems.  This is different from the
previous versions of C<IPC::System::Simple> and from Perl's
in-build C<system()> function, which can only handle 8-bit return values.

Versions of C<IPC::System::Simple> before v0.09 would not search
the C<PATH> environment variable when the multi-argument form of
C<run()> was called.  Versions from v0.09 onwards correctly search
the path provided the command is provided including the extension
(eg, C<notepad.exe> rather than just C<notepad>, or C<gvim.bat> rather
than just C<gvim>).

Signals are not supported on Windows systems.  Sending a signal
to a Windows process will usually cause it to exit with the signal
number used.

=head1 DIAGNOSTICS

=over 4

=item IPC::System::Simple::run called with no arguments

You attempted to call C<run> but did not provide any arguments at all.

=item IPC::System::Simple::run called with no command

You called C<run> with a list of acceptable exit values, but no
actual command.

=item IPC::System::Simple::run called with tainted argument '%s'

You called C<run> with tainted (untrusted) arguments, which is almost
certainly a bad idea.  To untaint your arguments you'll need to
pass your data through a regular expression and use the resulting
match variables.  See L<perlsec/Laundering and Detecting Tainted Data>
for more information.

=item IPC::System::Simple::run called with tainted environment $ENV{%s}

You called C<run> but part of your environment was tainted
(untrusted).  You should either delete the named environment
variable before calling C<run>, or set it to an untainted value
(usually one set inside your program).  See
L<perlsec/Cleaning Up Your Path> for more information.

=item "%s" failed to start: "%s"

The command specified did not even start.  It may not exist, or
you may not have permission to use it.  The reason it could not
start (as determined from C<$!>) will be provided.

=item "%s" unexpectedly returned exit value %d

The command ran successfully, but returned an exit value we did
not expect.  The value returned is reported.

=item "%s" died to signal "%s" (%d)

The command was killed by a signal.  The name of the signal
will be reported, or C<UNKNOWN> if it cannot be determined.  The
signal number is always reported.

=item Internal error in IPC::System::Simple - "%s" ran without exit value or signal

You've found a bug in C<IPC::System::Simple>.  It knows your command
ran successfully, but doesn't know how or why it stopped.  Please
report this error using the submission mechanism described in
BUGS below.

=back

=head1 DEPENDENCIES

This module depends upon L<Win32::Process> when used on Win32
system.  C<Win32::Process> is bundled as a core module in ActivePerl 5.6
and above.

There are no non-core dependencies on non-Win32 systems.

=head1 BUGS

Reporting of core-dumps is not yet implemented.

WIFSTOPPED status is not checked.

Signals are not supported under Win32 systems.

16-bit exit values are provided when C<run()> is called with multiple
arguments under Windows, but only 8-bit values are returned when
C<run()> is called with a single value.  We should always return 16-bit
value on systems that support them.

Please report bugs to L<http://rt.cpan.org/Public/Dist/Display.html?Name=IPC-System-Simple> .

=head1 SEE ALSO

L<POSIX> L<IPC::Run::Simple> L<perlipc> L<perlport> L<IPC::Run>
L<Win32::Process>

=head1 AUTHOR

Paul Fenwick E<lt>pjf@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2008 by Paul Fenwick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
