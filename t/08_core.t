#!/usr/bin/perl -w
use strict;
use Test::More;
use Config;

use constant SIGABRT => 6;

# Core dumps on OS X are complicated. See GH #5.

BEGIN {
    if ($^O eq 'darwin') {
        plan skip_all => "Coredump tests skipped under OS X/Darwin";
    }
}

BEGIN {
    eval { require BSD::Resource; BSD::Resource->import() };

    if ($@) {
        plan skip_all => "BSD::Resource required for coredump tests";
    } 
}

plan tests => 3;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
        $perl_path .= $Config{_exe}
                unless $perl_path =~ m/$Config{_exe}$/i;
}

use_ok("IPC::System::Simple","run");

chdir("t");

#Open a Perl script as backup input. If Perl is called with no arguments, it
#waits for input on STDIN.
#This ensures there's data on STDIN so it doesn't hang.
open my $input, '<', 'fail_test.pl' or die "Couldn't open perl script - $!";
my $fileno = fileno($input);
open STDIN, "<&", $fileno or die "Couldn't dup - $!";

my $rlimit_success = setrlimit(RLIMIT_CORE, RLIM_INFINITY, RLIM_INFINITY);

SKIP: {
	skip "setrlimit failed", 2 if not $rlimit_success;

	eval {
		run([1],$perl_path, 'signaler.pl', SIGABRT);
		seek($input, 0, 0); #Rewind STDIN. Necessary after every potential Perl call
	};

	like($@, qr/died to signal/, "Signal caught,   \$? = $?");
	like($@, qr/dumped core/,    "Coredump caught, \$? = $?");

        unlink('core');     # Clean up our core file, if it exists.
}
