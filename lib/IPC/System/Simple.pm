package IPC::System::Simple;

use 5.006;
use strict;
use warnings;
use Carp;
use List::Util qw(first);
use Config;
use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( run );
our $VERSION = '0.05';

my @Signal_from_number = split(' ', $Config{sig_name});

# Not all systems implment the WIFEXITED calls, but POSIX
# will always export them (even if they're just stubs that
# die with an error).  Test for the presence of a working
# WIFEXITED and friends, or define our own.

eval { WIFEXITED(0); };

if ($@ =~ /not defined POSIX macro/) {
	*WIFEXITED   = sub { $_[0] != 1 and not $_[0] & 127 };
	*WEXITSTATUS = sub { $_[0] >> 8  };
	*WIFSIGNALED = sub { $_[0] & 127 };
	*WTERMSIG    = sub { $_[0] & 127 };
}

# TODO - This doesn't look for core-dumps yet.
# TODO - WTF is a WIFSTOPPED and how can it hurt us?

sub run {

	my $valid_returns = [ 0 ];

	if (not @_) {
		croak "IPC::System::Simple::run called with no arguments";
	}

	if (ref $_[0] eq "ARRAY") {
		$valid_returns = shift(@_);
	}

	if (not @_) {
		croak "IPC::System::Simple::run called with no command";
	}

	my $command = shift(@_);

	system($command,@_);

	if ($? == -1) {
		croak qq{"$command" failed to start: "$!"};

	} elsif ( WIFEXITED( $? ) ) {
		my $exit_value = WEXITSTATUS( $? );

		if (not defined first { $_ == $exit_value } @$valid_returns) {
			croak qq{"$command" unexpectedly returned exit value $exit_value};
		}

		return $exit_value;

	} elsif ( WIFSIGNALED( $? ) ) {
		my $signal_no   = WTERMSIG( $? );
		my $signal_name = $Signal_from_number[$signal_no] || "UNKNOWN";

		croak qq{"$command" died to signal "$signal_name" ($signal_no)};

	} 

	croak qq{Internal error in IPC::System::Simple - "$command" ran without exit value or signal};

}

1;
__END__
=head1 NAME

IPC::System::Simple - Call system() commands with a minimum of fuss

=head1 SYNOPSIS

  use IPC::System::Simple qw(run);

  run("foo");

  run("foo",@args);

  my $exit_value = run([0..5], "foo", @args);

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

=head1 BUGS

Reporting of core-dumps is not yet implemented.

WIFSTOPPED status is not checked.

Signals are not supported under Win32 systems.

Please report bugs to L<http://rt.cpan.org/Public/Dist/Display.html?Name=IPC-System-Simple> .

=head1 SEE ALSO

L<POSIX> L<IPC::Run::Simple>

=head1 AUTHOR

Paul Fenwick E<lt>pjf@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Paul Fenwick

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
