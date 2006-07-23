#!/usr/bin/perl -w
use strict;
use Test::More 'no_plan';

use_ok("IPC::System::Simple","run");

run("t/exiter.pl",0);
ok(1);

eval {
	run("t/exiter.pl",1);
};

ok($@);
