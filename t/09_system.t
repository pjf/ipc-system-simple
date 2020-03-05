#!/usr/bin/perl -w
use strict;
use Test::More tests => 24;
use Config;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

use IPC::System::Simple qw(system);
chdir("t");	# Ignore return, since we may already be in t/

#Open a Perl script as backup input. If Perl is called with no arguments, it
#waits for input on STDIN.
#This ensures there's data on STDIN so it doesn't hang.
open my $input, '<', 'fail_test.pl' or die "Couldn't open perl script - $!";
my $fileno = fileno($input);
open STDIN, "<&$fileno" or die "Couldn't dup - $!";

system($perl_path,"exiter.pl",0);
seek($input, 0, 0);
ok(1,"Multi-arg system");

system("$perl_path exiter.pl 0");
seek($input, 0, 0);
ok(1,"Single-arg system success");

foreach (1..5,250..255) {

	eval {
		system($perl_path,"exiter.pl",$_);
		seek($input, 0, 0);
	};

	like($@, qr/unexpectedly returned exit value $_/, "Multi-arg system fail");
}

# Single arg tests


foreach (1..5,250..255) {

	eval {
		system("$perl_path exiter.pl $_");
		seek($input, 0, 0);
	};

	like($@, qr/unexpectedly returned exit value $_/, "Single-arg system fail" );
}

