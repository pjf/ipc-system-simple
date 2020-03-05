#!/usr/bin/perl -w
use strict;
use Test::More;
use Config;

use constant SIGKILL => 9;

if ($^O eq "MSWin32") {
	plan skip_all => "Signals not implemented on Win32";
} else {
	plan tests => 3;
}

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

run([1],$perl_path,"signaler.pl",0);
seek($input, 0, 0); #Rewind STDIN. Necessary after every potential Perl call
ok(1);

eval {
	run([1],$perl_path,"signaler.pl",SIGKILL);
	seek($input, 0, 0);
};

like($@, qr/died to signal/);
