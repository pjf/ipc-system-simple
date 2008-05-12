#!/usr/bin/perl -w
use strict;
use Test::More tests => 8;
use Config;

use_ok('IPC::System::Simple', qw(run capture));

# Run a command that doesn't exist.  The exit values
# 1 and 127 are special, as they indicate command-not-found
# from the Windows and Unix shells respectively.

# Bad command, run
eval { run([1,127],"xyzzy42this_command_does_not_exist","foo"); };
like ($@, qr{failed to start}, "Non-existant, run ");

# Bad calls to I::S::Simple

eval { run(); };
like($@, qr{IPC::System::Simple::run called with no arguments},"Empty call to run");

eval { capture(); };
like($@, qr{IPC::System::Simple::capture called with no arguments},"Empty call to capture");

eval { run([0..5]); };
like($@, qr{IPC::System::Simple::run called with no command},"No command passed to run");

eval { capture([0..5]); };
like($@, qr{IPC::System::Simple::capture called with no command},"No command passed to capture");

# Bad command, capture
eval { capture([1,127],"xyzzy42this_command_does_not_exist"); };
like ($@, qr{failed to start}, "Not existant, capture");

# Bad command, capture w/args
eval { capture([1,127],"xyzzy42this_command_does_not_exist",1); };
like ($@, qr{failed to start}, "Not existant, capture");
