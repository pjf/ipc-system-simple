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

#Close STDIN (and reopen to prevent warnings)
#If Perl is called with no arguments, it waits for input on STDIN.
close STDIN;
open STDIN, '<', '/dev/null';

run([1],$perl_path,"signaler.pl",0);
ok(1);

eval {
	run([1],$perl_path,"signaler.pl",SIGKILL);
};

like($@, qr/died to signal/);
