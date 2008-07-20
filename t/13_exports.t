#!/usr/bin/perl -w
use strict;
use Test::More tests => 1;

use IPC::System::Simple qw(
    run runx
    system systemx
    capture capturex
    $EXITVAL EXIT_ANY
);

ok(1, "Exports ok");
