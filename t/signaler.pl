#!/usr/bin/perl -w
use strict;
use warnings;

# This program always zaps itself with the signal specified.  Perfect
# for testing.  ;)

my $signal_number = shift(@ARGV) || 0;

kill($signal_number, $$);

exit(1);	# Exit failure if the signal wasn't very scary.
