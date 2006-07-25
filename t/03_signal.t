#!/usr/bin/perl -w
use strict;
use Test::More;

if ($^O eq "MSWin32") {
	plan skip_all => "Signals not implemented on Win32";
} else {
	plan tests => 3;
}

use_ok("IPC::System::Simple","run");

chdir("t");

run([1],"signaler.pl",0);
ok(1);

eval {
	run([1],"signaler.pl",2);		# SIGINT on most systems.
};

like($@, qr/died to signal/);
