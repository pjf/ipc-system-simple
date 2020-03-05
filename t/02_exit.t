#!/usr/bin/perl -w
use strict;
use Test::More tests => 28;
use Config;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

use IPC::System::Simple qw(run EXIT_ANY);
chdir("t");	# Ignore return, since we may already be in t/

#Open a Perl script as backup input. If Perl is called with no arguments, it
#waits for input on STDIN.
#This ensures there's data on STDIN so it doesn't hang.
open my $input, '<', 'fail_test.pl' or die "Couldn't open perl script - $!";
my $fileno = fileno($input);
open STDIN, "<&", $fileno or die "Couldn't dup - $!";

run($perl_path,"exiter.pl",0);
seek($input, 0, 0); #Rewind STDIN. Necessary after every potential Perl call
ok(1,"Multi-arg implicit zero allowed");

foreach (1..5,250..255) {

	eval {
		run($perl_path,"exiter.pl",$_);
		seek($input, 0, 0);
	};

	like($@, qr/unexpectedly returned exit value $_/ );
}

# Single arg tests

run("$perl_path exiter.pl 0");
seek($input, 0, 0);
ok(1,"Implicit zero allowed");

foreach (1..5,250..255) {

	eval {
		run("$perl_path exiter.pl $_");
		seek($input, 0, 0);
	};

	like($@, qr/unexpectedly returned exit value $_/ );
}

# Testing allowable return values

run([0], "$perl_path exiter.pl 0");
seek($input, 0, 0);
ok(1,"Explcit zero allowed");

run([1], "$perl_path exiter.pl 1");
seek($input, 0, 0);
ok(1,"Explicit allow of exit status 1");

run([-1], "$perl_path exiter.pl 5");
seek($input, 0, 0);
ok(1,"Exit-all emulation via [-1] allowed");

run(EXIT_ANY, "$perl_path exiter.pl 5");
seek($input, 0, 0);
ok(1,"Exit-all via EXIT_ANY constant");
