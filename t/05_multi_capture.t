#!/usr/bin/perl -w
use strict;
use Config;
use Test::More;
use constant NO_SUCH_CMD => "this_command_had_better_not_exist_either";

plan tests => 11;

# We want to invoke our sub-commands using Perl.

my $perl_path = $Config{perlpath};

if ($^O ne 'VMS') {
	$perl_path .= $Config{_exe}
		unless $perl_path =~ m/$Config{_exe}$/i;
}

use_ok("IPC::System::Simple","capture");
chdir("t");

# The tests below for $/ are left in, even though IPC::System::Simple
# never touches $/

# Scalar capture

my $output = capture($perl_path,"output.pl",0);
ok(1);

is($output,"Hello\nGoodbye\n","Scalar capture");
is($/,"\n",'$/ intact');

# List capture

my @output = capture($perl_path,"output.pl",0);
ok(1);

is_deeply(\@output,["Hello\n", "Goodbye\n"],"List capture");
is($/,"\n",'$/ intact');

# List capture with odd $/

{
	local $/ = "e";
	my @odd_output = capture($perl_path,"output.pl",0);
	ok(1);

	is_deeply(\@odd_output,["He","llo\nGoodbye","\n"], 'Odd $/ capture');

}

my $no_output;
eval {
        $no_output = capture(NO_SUCH_CMD,1);
};

like($@,qr/failed to start/, "failed capture");
is($no_output,undef, "No output from failed command");
