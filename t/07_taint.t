#!/usr/bin/perl -wT
use strict;
use Test::More;
use Scalar::Util qw(tainted);
use Config;

if (exists $INC{"Portable.pm"}) {
  plan skip_all => 'Cannot test tainted perlpath under Portable perl';
} else {
  plan tests => 13;
}

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
        $perl_path .= $Config{_exe}
                unless $perl_path =~ m/$Config{_exe}$/i;
}

ok(! tainted($perl_path), '$perl_path is clean');

use_ok("IPC::System::Simple","run","capture");

chdir("t");     # Ignore return, since we may already be in t/

my $taint = $0 . "foo";	# ."foo" to avoid zero length
ok(tainted($taint),"Sanity - executable name is tainted");

my $evil_zero = 1 - (length($taint) / length($taint));

ok(tainted($evil_zero),"Sanity - Evil zero is tainted");
is($evil_zero,"0","Sanity - Evil zero is still zero");

SKIP: {
	skip('$ENV{PATH} is clean',2) unless tainted $ENV{PATH};

	eval { run("$perl_path exiter.pl 0"); };
	like($@,qr{called with tainted environment},"Single-arg, tainted ENV");

	eval { run($perl_path, "exiter.pl", 0); };
	like($@,qr{called with tainted environment},"Multi-arg, tainted ENV");
}

delete @ENV{qw(PATH IFS CDPATH ENV BASH_ENV PERL5SHELL DCL$PATH)};

eval { run("$perl_path exiter.pl $evil_zero"); };
like($@,qr{called with tainted argument},"Single-arg, tainted data");

eval { run($perl_path, "exiter.pl", $evil_zero); };
like($@,qr{called with tainted argument},"multi-arg, tainted data");

eval { run("$perl_path exiter.pl 0"); };
is($@, "", "Single-arg, clean data and ENV");

eval { run($perl_path, "exiter.pl", 0); };
is($@, "", "Multi-arg, clean data and ENV");

my $data = eval { capture($perl_path, "exiter.pl", 0) };
ok(tainted($data), "Returns of multi-arg capture should be tainted");

$data = eval { capture("$perl_path exiter.pl 0") };
ok(tainted($data), "Returns of single-arg capture should be tainted");

