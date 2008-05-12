#!/usr/bin/perl -w
use strict;
use Test::More tests => 3;
use IPC::System::Simple;

# These tests are for testing internal subroutines, and may change
# in the future.

*_check_exit = \&IPC::System::Simple::_check_exit;


is(_check_exit("command",1,[0..5]), 1, "Successful exit");

eval { 
	_check_exit("command",127,[0..5], 1);
};

like($@,qr{unexpectedly returned exit value},"Failed exit");

SKIP: {
	skip("Non-Win32 only", 1) if IPC::System::Simple::WINDOWS;

	# _spawn_or_die should croak on non-Windows systems.

	eval {
		IPC::System::Simple::_spawn_or_die();
	};

	like($@, qr{Internal error},"_spawn_or_die fails under non-Win32");
};
