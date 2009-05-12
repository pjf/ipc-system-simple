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

my $status = eval { systemx("does_not_exist_972", "l") } || $@; my $line = __LINE__;
ok( !$status->is_success, "not success" );
ok( !$status->started_ok, "bad start"   );
like( $status->file, qr/19_exceptions/ );
like( $status->line, qr/$line/ );
like( $status->package, qr/19th_test_suite/ );
like( $status->caller, qr/runx/ );
