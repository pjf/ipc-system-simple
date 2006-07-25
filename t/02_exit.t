#!/usr/bin/perl -w
use strict;
use Test::More tests => 3;

use_ok("IPC::System::Simple","run");
chdir("t");

run("exiter.pl",0);
ok(1);

eval {
	run("exiter.pl",1);
};

like($@, qr/unexpectedly returned exit value 1/ );
