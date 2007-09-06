package IPC::System::Simple;

use 5.006;
use strict;
use warnings;
use Carp;
use List::Util qw(first);
use Config;
use constant WINDOWS => ($^O eq 'MSWin32');
use if WINDOWS, 'Win32::Process', qw(INFINITE NORMAL_PRIORITY_CLASS);
use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( run capture $EXITVAL );
our $VERSION = '0.06';
our $EXITVAL = -1;

my @Signal_from_number = split(' ', $Config{sig_name});

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
	my ($valid_returns, $command, @args) = _process_args(@_);

	# With the wonders of constant folding the following code
	# is completely optimised away under non-windows systems.

	# The following essentially emulates multi-argument system,
	# bypassing the shell entirely.

	if (WINDOWS and @args) {
		our $EXITVAL = -1;
		my $pid;
		my $success = Win32::Process::Create(
			$pid,$command,"$command @args",1,NORMAL_PRIORITY_CLASS,"."
		);
		if (not $success) {
			croak sprintf(
				q{"%s" failed to start: "%s"},
				$command, $^E
			);
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

# This subroutine performs the difficult task of interpreting
# $?.  It's not intended to be called directly, as it will
# croak on errors, and its implementation and interface may
# change in the future.

sub _process_child_error {
	my ($child_error, $command, $valid_returns) = @_;
	
	$EXITVAL = -1;

	if ($child_error == -1) {
		croak qq{"$command" failed to start: "$!"};

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

  use IPC::System::Simple qw(run $EXITVAL);

  run("some_command");        # Run a command and check exit status

  run("some_command",@args);  # Run a command, avoiding the shell

  my $exit_value = run([0..5], "some_command", @args);

  print "some_command exited with status $EXITVAL\n";

=head1 DESCRIPTION

Calling Perl's in-built C<system()> function is easy, but checking
the results can be hard.  C<IPC::System::Simple> aims to make
life easy for the I<common cases> of calling system.

C<IPC::System::Simple> provides a single subroutine, called
C<run>, that executes a command using the same semantics is
Perl's built-in C<system>:

	use IPC::System::Simple qw(run);

	run("cat *.txt");		# Execute command via the shell
	run("cat","/etc/motd");		# Execute command without shell

In the case where the command returns an unexpected status,
C<run> will throw an exception, which is not caught will terminate
your program with an error.

Capturing an the exception is easy:

	eval {
		run("cat *.txt");
	};

	if ($@) {
		print "Something went wrong - $@\n";
	}

See the diagnostics section below for more details.

C<IPC::System::Simple> considers the following to be unexpected,
and worthy of exception:

=over 4

=item *

Failing to start entirely (eg, command not found, permission denied).

=item *

Returning an exit value other than zero (but see below).

=item *

Being killed by a signal.

=back

You may specify a range of values which are considered acceptable
return values by passing an I<array reference> as the first argument:

	run( [0..5], "cat *.txt");	# Exit values 0-5 are OK

	run( [0..255], "cat *.txt");	# Any exit value is OK

The C<run> subroutine returns the exit value of the process:

	my $exit_value = run( [0..5], "cat *.txt");

	print "Program exited with value $exit_value\n";

=head2 $EXITVAL

After a call to C<run> or C<capture> the exit value of the command
is always available in C<$IPC::System::Simple::EXITVAL>.  This will
be set to C<-1> if the command did not exit normally (eg,
being terminated by a signal) or did not start.

=head2 WINDOWS-SPECIFIC NOTES

As of C<IPC::System::Simple> v0.06, the C<run> subroutine I<when
called with multiple arguments> will make available the full 16-bit
return value on Win32 systems.  This is different from the
previous versions of C<IPC::System::Simple> and from Perl's
in-build C<system()> function, which can only handle 8-bit return values.

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

=item "%s" failed to start: "%s"

The command specified did not even start.  It may not exist, or
you may not have permission to use it.  The reason it could not
start (as determined from C<$!>) will be provided.

=item "%s" unexpectedly returned exit value %d

The command ran successful, but returned an exit value we did
not expect.  The value returned is reported.

=item "%s" died to signal "%s" (%d)

The command was killed by a signal.  The name of the signal
will be reported, or C<UNKNOWN> if it cannot be determined.  The
signal number is always reported.

=item Internal error in IPC::System::Simple - "%s" ran without exit value or signal

You've found a bug in C<IPC::System::Simple>.  It knows your command
ran successful, but doesn't know how or why it stopped.  Please
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

L<POSIX> L<IPC::Run::Simple> L<perlipc> L<perlport> L<IPC::Run> L<Win32::Process>

=head1 AUTHOR

Paul Fenwick E<lt>pjf@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006-2007 by Paul Fenwick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
