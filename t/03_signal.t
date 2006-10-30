#!/usr/bin/perl -w
use strict;
use Test::More;
use Config;

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

run([1],$perl_path,"signaler.pl",0);
ok(1);

eval {
	run([1],$perl_path,"signaler.pl",2);	# SIGINT on most systems.
};

like($@, qr/died to signal/);
