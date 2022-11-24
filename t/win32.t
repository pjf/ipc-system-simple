#!/usr/bin/perl -w
use strict;
use Test::More;
use File::Basename qw(fileparse);
use IPC::System::Simple qw(run capture $EXITVAL capturex);
use Config;

BEGIN {
    if ($^O ne "MSWin32") {
	    plan skip_all => "Win32 only tests";
    }
}

# This number needs to fit into an 8 bit integer
use constant SMALL_EXIT => 42;

# This number needs to fit into a 16 bit integer, but not an 8 bit integer.
use constant BIG_EXIT => 1000;

# This needs to fit into a 32-bit integer, but not a 16-bit integer.
use constant HUGE_EXIT => 100_000;

# This command should allow us to exit with a specific value.
use constant CMD => join ' ', @{ &IPC::System::Simple::WINDOWS_SHELL };

# These are used in the testing of commands in paths which contain spaces.
use constant CMD_WITH_SPACES        => 'dir with spaces\hello.exe';
use constant CMD_WITH_SPACES_OUTPUT => "Hello World\n";

plan tests => 37;

my $perl_path = $Config{perlpath};
$perl_path .= $Config{_exe} unless $perl_path =~ m/$Config{_exe}$/i;

my ($perl_exe, $perl_dir) = fileparse($perl_path);

my ($raw_perl) = ($perl_exe =~ /^(.*)\.exe$/);

ok($raw_perl, "Have perl executables with and w/o extensions.");

chdir("t");

#Close STDIN (and reopen to prevent warnings)
#If Perl is called with no arguments, it waits for input on STDIN.
close STDIN;
open STDIN, '<', '/dev/null';

# Check for 16 and 32 bit returns.

foreach my $big_exitval (SMALL_EXIT, BIG_EXIT, HUGE_EXIT) {

    my $exit;
    # XXX Ideally, we would find a way to test the multi-argument form, too,
    # but cmd.exe no longer works with that form, because all args are quoted,
    # and /x/d/c must not be.
    eval {
        $exit = run([$big_exitval], CMD . qq{ "exit $big_exitval"});
    };

    is($@,"","Running with $big_exitval ok");
    is($exit,$big_exitval,"$big_exitval exit value");

    my $capture;

    eval {
	$capture = capture([$big_exitval], CMD . qq{ exit $big_exitval"});
    };

    is($@,"","Capturing with $big_exitval ok");
    is($EXITVAL,$big_exitval,"Capture ok with $big_exitval exit value");
}

# As of June 2008, all versions of Perl under Win32 have a bug where
# they can execute a command twice if it returns -1 and $! is set
# to ENOENT or ENOEXEC before system is called.  

# TODO: Test to see if we're running on a Perl that stuffers from
# this bug.

# TODO: Make sure that we *don't* suffer from this bug.

# Testing to ensure that our PATH gets respected...

$ENV{PATH} = "";

eval { run($perl_exe,"-e1"); };
like($@,qr/failed to start/,"No calling perl when not in path");

eval { capture($perl_exe,"-e1"); };
like($@, qr/failed to start/, "Capture can't find perl when not in path");

eval { run($raw_perl,"-e1"); };
like($@, qr/failed to start/, "Can't find raw perl when not in path, either");

$ENV{PATH} = $perl_dir;

run($perl_exe,"-e1");
ok(1,"run found perl in path");

run($raw_perl,"-e1");
ok(1,"run found raw perl in path");

my $capture = capture($perl_exe,"-v");
ok(1,"capture found perl in path");
like($capture, qr/Larry Wall/, "Capture text successful");

$capture = capture($raw_perl,"-v");
ok(1,"capture found raw perl in path");
like($capture, qr/Larry Wall/, "Capture text successful");

$capture = capture("$perl_exe -v");
ok(1,"capture found single-arg perl in path");
like($capture, qr/Larry Wall/, "Single-arg Capture text successful");

$capture = capture("$raw_perl -v");
ok(1,"capture found single-arg raw perl in path");
like($capture, qr/Larry Wall/, "Single-arg Capture text successful");

$ENV{PATH} = "$ENV{SystemRoot};$perl_dir;$ENV{SystemRoot}\\System32";

run($perl_exe,"-e1");
ok(1,"perl found in multi-part path");

run($raw_perl,"-e1");
ok(1,"raw perl found in multi-part path");

# RT #48319 - capture/capturex could break STDOUT when running
# unknown commands.  The following spawns another process to
# use capture.  In buggy versions, the '2' is never printed.
# In bugfixed versions, it is.

my $output = capture(
	$^X, '-MIPC::System::Simple=capture',
	'-e', q(print 1; eval { capture(q(nosuchcmd)); }; print 2; exit 0;)
);

is($output,"12","RT #48319 - Check for STDOUT replumbing");

SKIP: {
	skip("Inconsistent results between AppVeyor and CPANtesters", 8)
        unless $ENV{AUTHOR_TESTING};
     
    # Check to ensure we can run commands that include spaces.
    $output = eval { capturex(CMD_WITH_SPACES, 'ignore'); };
    is($@, "", "command with spaces should not error (capturex multi)");
    is($output, CMD_WITH_SPACES_OUTPUT, "...and give correct output");

    $output = eval { capturex(CMD_WITH_SPACES); };
    is($@, "", "command with spaces should not error (capturex single)");
    is($output, CMD_WITH_SPACES_OUTPUT, "...and give correct output");

    $output = eval { capture(CMD_WITH_SPACES, 'ignore'); };
    is($@, "", "command with spaces should not error (capture multi)");
    is($output, CMD_WITH_SPACES_OUTPUT, "...and give correct output");

    $output = eval { capture('"' . CMD_WITH_SPACES . '"'); };
    is($@, "", "command with spaces should not error (capture quoted)");
    is($output, CMD_WITH_SPACES_OUTPUT, "...and give correct output");
} # End SKIP block
