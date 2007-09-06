#!/usr/bin/perl -w
use strict;
use Test::More;
use Config;

# This number needs to fit into a 16 bit integer, but not an 8 bit integer.
use constant BIG_EXIT => 1000;

if ($^O ne "MSWin32") {
	plan skip_all => "Win32 only tests";
}

my $perl_path = $Config{perlpath};
$perl_path .= $Config{_exe} unless $perl_path =~ m/$Config{_exe}$/i;

plan tests => 2;

use_ok("IPC::System::Simple","run");

chdir("t");

my $exit = run([1000], $perl_path, "exiter.pl",BIG_EXIT);

is($exit,BIG_EXIT,"16 bit exit value");
