#!/usr/bin/perl -w
use strict;
use Test::More tests => 9;
use Config;
use constant NO_SUCH_CMD => "this_command_had_better_not_exist";

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

# Win32 systems don't support multi-arg pipes.  Our
# simple captures will begin with single-arg tests.
my $output_exe = "$perl_path output.pl";

use_ok("IPC::System::Simple","capture");
chdir("t");

# Scalar capture

my $output = capture($output_exe);
ok(1);

is($output,"Hello\nGoodbye\n","Scalar capture");
is($/,"\n","IFS intact");

# List capture

my @output = capture($output_exe);
ok(1);

is_deeply(\@output,["Hello\n", "Goodbye\n"],"List capture");
is($/,"\n","IFS intact");

my $no_output;
eval {
	$no_output = capture(NO_SUCH_CMD,1);
};

like($@,qr/failed to start/, "failed capture");
is($no_output,undef, "No output from failed command");
