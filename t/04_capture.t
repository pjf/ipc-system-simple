#!/usr/bin/perl -w
use strict;
# use Test::More tests => 7;
use Test::More skip_all => "Unimplemented";
use Config;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

# Win32 systms don't support multi-arg pipes.  Our
# simple captures will begin with single-arg tests.
my $output_exe = "$perl_path output.pl";

use_ok("IPC::System::Simple","capture");
chdir("t");

# Scalar capture

my $output = capture($output_exe);
ok(1);

is($output,"Hello\nGoodbye\n","Scalar capture");
is($/,"\n","IFS intact");

# List capture

my @output = capture($output_exe);
ok(1);

is_deeply(\@output,["Hello\n", "Goodbye\n"],"List capture");
is($/,"\n","IFS intact");

