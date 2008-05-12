#!/usr/bin/perl -w
use strict;

use Test::More;
eval "use Test::Pod::Coverage 1.00";	## no critic
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD" if $@;
all_pod_coverage_ok();
