#!/usr/bin/perl -wT
use strict;
use Test::More tests => 5;

use_ok("IPC::System::Simple","run");

# A formatting bug caused ISS to mention its name twice in
# diagnostics.  These tests make sure it's fixed.


eval {
	run($^X);
};

like($@,qr{^IPC::System::Simple::run called with tainted argument},"Taint pkg only once");

eval {
	run(1);
};

like($@,qr{^IPC::System::Simple::run called with tainted environment},"Taint env only once");

# Delete everything in %ENV so we can't get taint errors.

my @keys = keys %ENV;

delete $ENV{$_} foreach @keys;

eval {
	run();
};

like($@,qr{^IPC::System::Simple::run called with no arguments},"Package mentioned only once");

eval {
	run([0]);
};

like($@,qr{^IPC::System::Simple::run called with no command},"Package mentioned only once");
