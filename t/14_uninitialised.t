#!/usr/bin/perl -w
use strict;
use warnings;
use Test::More;

use IPC::System::Simple qw(systemx);

eval "use Test::NoWarnings qw(had_no_warnings clear_warnings)";

plan skip_all => "Test::NoWarnings required for testing undef warnings" if $@;

plan 'no_plan';

# Passing undef to system functions should produce a nice message,
# not a warning and a malformed message.


eval {
    systemx(undef,1);
};

like($@, qr/undef/, "systemx() should check for undef");
