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

TODO: {
    local $TODO = "Checking for undef not yet implemented";

    eval {
        systemx(undef,1);
    };

    like($@, qr/undef/, "systemx() should check for undef");

    # We call had_no_warnings manually so it can be marked
    # as a to-do test.
    had_no_warnings();

}

# Since we manually tested our warnings, we clear them
# before script exit.
clear_warnings();
