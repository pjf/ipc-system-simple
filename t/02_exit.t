#!/usr/bin/perl -w
use strict;
use Test::More tests => 25;
use Config;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

use_ok("IPC::System::Simple","run");
chdir("t");	# Ignore return, since we may already be in t/

run($perl_path,"exiter.pl",0);
ok(1);

foreach (1..5,250..255) {

	eval {
		run($perl_path,"exiter.pl",$_);
	};

	like($@, qr/unexpectedly returned exit value $_/ );
}

# Single arg tests

run("$perl_path exiter.pl 0");
ok(1);

foreach (1..5,250..255) {

	eval {
		run("$perl_path exiter.pl $_");
	};

	like($@, qr/unexpectedly returned exit value $_/ );
}
