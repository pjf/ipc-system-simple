#!/usr/bin/perl -wT
use strict;
use Test::More tests => 13;
use Scalar::Util qw(tainted);
use Config;

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
        $perl_path .= $Config{_exe}
                unless $perl_path =~ m/$Config{_exe}$/i;
}

ok(! tainted($perl_path), '$perl_path is clean');

use_ok("IPC::System::Simple","run","capture");

chdir("t");     # Ignore return, since we may already be in t/

#Open a Perl script as backup input. If Perl is called with no arguments, it
#waits for input on STDIN.
#This ensures there's data on STDIN so it doesn't hang.
open my $input, '<', 'fail_test.pl' or die "Couldn't open perl script - $!";
my $fileno = fileno($input);
open STDIN, "<&$fileno" or die "Couldn't dup - $!";

my $taint = $0 . "foo";	# ."foo" to avoid zero length
ok(tainted($taint),"Sanity - executable name is tainted");

my $evil_zero = 1 - (length($taint) / length($taint));

ok(tainted($evil_zero),"Sanity - Evil zero is tainted");
is($evil_zero,"0","Sanity - Evil zero is still zero");

SKIP: {
	skip('$ENV{PATH} is clean',2) unless tainted $ENV{PATH};

	eval { run("$perl_path exiter.pl 0"); };
	seek($input, 0, 0); #Rewind STDIN. Necessary after every potential Perl call
	like($@,qr{called with tainted environment},"Single-arg, tainted ENV");

	eval { run($perl_path, "exiter.pl", 0); };
	seek($input, 0, 0);
	like($@,qr{called with tainted environment},"Multi-arg, tainted ENV");
}

delete @ENV{qw(PATH IFS CDPATH ENV BASH_ENV PERL5SHELL DCL$PATH)};

eval { run("$perl_path exiter.pl $evil_zero"); };
seek($input, 0, 0);
like($@,qr{called with tainted argument},"Single-arg, tainted data");

eval { run($perl_path, "exiter.pl", $evil_zero); };
seek($input, 0, 0);
like($@,qr{called with tainted argument},"multi-arg, tainted data");

eval { run("$perl_path exiter.pl 0"); };
seek($input, 0, 0);
is($@, "", "Single-arg, clean data and ENV");

eval { run($perl_path, "exiter.pl", 0); };
seek($input, 0, 0);
is($@, "", "Multi-arg, clean data and ENV");

my $data = eval { capture($perl_path, "exiter.pl", 0) };
seek($input, 0, 0);
ok(tainted($data), "Returns of multi-arg capture should be tainted");

$data = eval { capture("$perl_path exiter.pl 0") };
seek($input, 0, 0);
ok(tainted($data), "Returns of single-arg capture should be tainted");

