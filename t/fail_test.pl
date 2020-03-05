#!/usr/bin/perl -w
use strict;
use warnings;

#Perl script that prints "Test failed."
#Intended as a safeguard for testing argument passing, possibly only on Win32
#If no arguments are given, Perl will wait for input on STDIN.
#With no input, the test hangs.

print "Test failed.\n";
