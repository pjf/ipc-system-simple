#!/usr/bin/perl -w
use strict;
use warnings;

# This program always exits with the value supplied.  Perfect
# for testing.  ;)

my $exit_value = shift(@ARGV) || 0;

exit($exit_value);
