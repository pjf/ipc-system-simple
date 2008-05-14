#!/usr/bin/perl -w
use strict;
use Config;
use Test::More;
use constant NO_SUCH_CMD => "this_command_had_better_not_exist_either";
use constant NOT_AN_EXE  => "not_an_exe.txt";

plan tests => 14;

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

# Running Perl -v

my $perl_output = capture($perl_path,"-v");
like($perl_output, qr{Larry Wall}, "perl -v contains Larry");

SKIP: {

	# Considering making these tests depend upon the OS,
	# as well as $ENV{AUTHOR_TEST}, since different systems
	# will have different ways of expressing their displeasure
	# at executing a file that's not executable.

	skip('Author test.  Set $ENV{TEST_AUTHOR} to true to run', 2)
		unless $ENV{TEST_AUTHOR};

	chmod(0,NOT_AN_EXE);
	eval { capture(NOT_AN_EXE,1); };

	like($@, qr{Permission denied|No such file|The system cannot find the file specified}, "Permission denied on non-exe" );
	like($@, qr{failed to start}, "Non-exe failed to start" );

}
