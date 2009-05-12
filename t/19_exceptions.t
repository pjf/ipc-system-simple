#!/usr/bin/perl -w

package _19th_test_suite;
use strict;
use warnings;

use Config;
use Test::More;
use IPC::System::Simple qw(systemx);

my $perl_path = $Config{perlpath};
my $res;

plan 'no_plan';

$res = eval { systemx($perl_path, "t/exiter.pl", 0) };
$res = $@ unless defined $res;
ok( $res->is_success, "success!" );
is( $res, 0, "0's ok" );

$res = eval { systemx($perl_path, "t/exiter.pl", 1) };
$res = $@ unless ref $res;
ok( !$res->is_success, "not success" );
ok( $res->started_ok,  "but, did start ok" );
is( $res->exit_value, 1, "1's not ok"  );
like( $res, qr/unexpectedly returned exit value 1/, "1's not ok"  );

is( IPC::System::Simple::process_child_error(0,   {command=>"ls", args=>[qw(-al)], allowable_returns=>[0]}), 0, "boring exit(0)");
is( IPC::System::Simple::process_child_error(256, {command=>"ls", args=>[qw(-al)], allowable_returns=>[1]}), 1, "boring exit(1)");

like( IPC::System::Simple::process_child_error(256, {command=>"ls", args=>[qw(-al)], allowable_returns=>[0]}), qr/unexpectedly returned exit value 1/, "exciting exit(1)");

$res = eval { systemx("does_not_exist_972", "l") }; my $line = __LINE__;
$res = $@ unless ref $res;
ok( !$res->is_success, "not success" );
ok( !$res->started_ok, "bad start"   );
like( $res->file, qr/19_exceptions/ );
like( $res->line, qr/$line/ );
like( $res->package, qr/19th_test_suite/ );
like( $res->caller, qr/runx/ );

$res = eval { systemx($perl_path, "t/signaler.pl", 15) };
$res = $@ unless defined $res;
ok( !$res->is_success, "success-kill" );
ok( $res->started_ok, "started start" );
ok( !$res->dumped_core, "not a core" );
is( $res->signal_number, 15, "killed with 15!" );

$res = eval { systemx($perl_path, "t/signaler.pl", 11) };
$res = $@ unless defined $res;
ok( !$res->is_success, "success-seg" );
ok( $res->started_ok, "started start" );
is( $res->signal_number, 11, "killed with 11!" );

my $linux = `uname -o`;
SKIP: {
    skip "sig11 is a core only on certain platforms...", 1 unless $linux =~ m/linux/i;

    ok( $res->dumped_core, "corepile" );
}
