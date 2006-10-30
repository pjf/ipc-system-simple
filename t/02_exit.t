#!/usr/bin/perl -w
use strict;
use Test::More tests => 3;
use Config;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

use_ok("IPC::System::Simple","run");
chdir("t");

run($perl_path,"exiter.pl",0);
ok(1);

eval {
	run($perl_path,"exiter.pl",1);
};

like($@, qr/unexpectedly returned exit value 1/ );
