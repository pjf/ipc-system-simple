#!/usr/bin/perl -w
use strict;
use Test::More 'no_plan';

use_ok("IPC::System::Simple","run");

run([1],"t/signaler.pl",0);
ok(1);

eval {
	run("t/signaler.pl",2);		# SIGINT on most systems.
};

ok($@);
