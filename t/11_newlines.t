#!/usr/bin/perl -w
use strict;
use IPC::System::Simple qw(run capture);
use Config;
use Test::More tests => 6;

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
    $perl_path .= $Config{_exe}
        unless $perl_path =~ m/$Config{_exe}$/i;
}

eval { run( "$perl_path -e1" ) };
is($@, "", 'Run works with single arg');

eval { run( "$perl_path -e1\n" ) };
is($@, "", 'Run works with \\n');

eval { run( "$perl_path -e1\r\n") };
is($@, "", 'Run works with \r\n');

eval { capture( "$perl_path -e1" ) };
is($@, "", 'Run works with single arg');

eval { capture( "$perl_path -e1\n" ) };
is($@, "", 'Run works with \\n');

eval { capture( "$perl_path -e1\r\n") };
is($@, "", 'Run works with \r\n');
