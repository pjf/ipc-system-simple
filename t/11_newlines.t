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

chdir("t");	# Ignore return, since we may already be in t/
#Open a Perl script as backup input. If Perl is called with no arguments, it
#waits for input on STDIN.
#This ensures there's data on STDIN so it doesn't hang.
open my $input, '<', 'fail_test.pl' or die "Couldn't open perl script - $!";
my $fileno = fileno($input);
open STDIN, "<&", $fileno or die "Couldn't dup - $!";

eval { run( "$perl_path -e1" ) };
seek($input, 0, 0); #Rewind STDIN. Necessary after every potential Perl call
is($@, "", 'Run works with single arg');

eval { run( "$perl_path -e1\n" ) };
seek($input, 0, 0);
is($@, "", 'Run works with \\n');

eval { run( "$perl_path -e1\r\n") };
seek($input, 0, 0);
is($@, "", 'Run works with \r\n');

eval { capture( "$perl_path -e1" ) };
seek($input, 0, 0);
is($@, "", 'Run works with single arg');

eval { capture( "$perl_path -e1\n" ) };
seek($input, 0, 0);
is($@, "", 'Run works with \\n');

eval { capture( "$perl_path -e1\r\n") };
seek($input, 0, 0);
is($@, "", 'Run works with \r\n');
