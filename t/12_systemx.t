#!/usr/bin/perl -w
use strict;

use IPC::System::Simple qw(system systemx capture capturex);
use Config;
use Test::More tests => 7;

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
        $perl_path .= $Config{_exe}
                unless $perl_path =~ m/$Config{_exe}$/i;
}

chdir("t");     # Ignore return, since we may already be in t/

my $exit_test = "$perl_path exiter.pl 0";

eval {
    system($exit_test);
};

is($@,"","system invokes the shell");

eval {
    systemx($exit_test);
};
ok($@,"systemx does not invoke the shell");

eval {
    systemx($perl_path, "exiter.pl", 0);
};
is($@,"", "multi-arg systemx works");

my $output_test = "$perl_path output.pl";

my $output;

eval {
    $output = capture($output_test);
};
like($output, qr/Hello/, "capture invokes the shell");

undef $output;

eval {
    $output = capturex($output_test);
};

ok($@, "capturex does not invoke the shell");

eval {
    $output = capturex($perl_path, "output.pl");
};

is($@,"","multi-arg capturex works");

like($output, qr/Hello/, "multi-arg capturex captures");
