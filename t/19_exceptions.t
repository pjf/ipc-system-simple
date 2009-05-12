#!/usr/bin/perl -w
use strict;
use warnings;

use Config;
use Test::More;
use IPC::System::Simple qw(systemx);

my $perl_path = $Config{perlpath};
my $res;

plan 'no_plan';

$res = eval { systemx($perl_path, "t/exiter.pl", 0) };
$res = $@ unless ref $res;
ok( $res->is_success, "success!" );
is( $res, 0, "0's ok" );

$res = eval { systemx($perl_path, "t/exiter.pl", 1) };
$res = $@ unless ref $res;
ok( !$res->is_success, "not success" );
is( $res->exit_value, 1, "1's not ok"  );
like( $res, qr/unexpectedly returned exit value 1/, "1's not ok"  );
