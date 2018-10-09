#!/usr/bin/perl -w

use strict;

use Test::More tests => 56;
use IPC::System::Simple qw(run runx system systemx capture capturex);
use Config;
use File::Basename qw(fileparse);

my $perl = $Config{perlpath};
$perl .= $Config{_exe} if $^O ne 'VMS' && $perl !~ m/$Config{_exe}$/i;
my $tmp = 'test.tmp';

my $script = qq{
    open my \$fh, '>', '$tmp' or die "Cannot write to $tmp: \$!\\n";
    print {\$fh} "\$_\\n" for \@ARGV;
};

chdir 't';

END {
    unlink $tmp;
}

my $slurp = sub {
    open my $fh, '<', $tmp or die "Cannot read $tmp: $!\n";
    return join '', <$fh>;
};

for my $spec (
    ['single arg', 'foo'],
    ['multiple args', 'x', 'y', 'z'],
    ['arg with spaces', 'foo', 'bar baz'],
) {
    my ($desc, @args) = @{ $spec };
    my $exp = join "\n", @args, '';

    # Test run.
    my $exit = eval { run $perl, '-e', $script, @args };
    is $@, "", "Should have no error from runx with $desc";
    is $exit, 0, "Should have exit 0 from runx with $desc";
    is $slurp->(), $exp, "Should have passed $desc from run";

    # Test system.
    $exit = eval { system $perl, '-e', $script, @args };
    is $@, "", "Should have no error from systemx with $desc";
    is $exit, 0, "Should have exit 0 from systemx with $desc";
    is $slurp->(), $exp, "Should have passed $desc from system";

    # Test runx.
    $exit = eval { runx $perl, '-e', $script, @args };
    is $@, "", "Should have no error from runx with $desc";
    is $exit, 0, "Should have exit 0 from runx with $desc";
    is $slurp->(), $exp, "Should have passed $desc from runx";

    # Test systemx.
    $exit = eval { systemx $perl, '-e', $script, @args };
    is $@, "", "Should have no error from systemx with $desc";
    is $exit, 0, "Should have exit 0 from systemx with $desc";
    is $slurp->(), $exp, "Should have passed $desc from systemx";

    # Test capture.
    my $output = eval { capture $perl, '-e', 'print "$_\n" for @ARGV', @args };
    is $@, "", "Should have no error from capture with $desc";
    is $output, $exp, "Should have passed $desc from capture";

    # Test capturex.
    $output = eval { capturex $perl, '-e', 'print "$_\n" for @ARGV', @args };
    is $@, "", "Should have no error from capturex with $desc";
    is $output, $exp, "Should have passed $desc from capturex";
}

# Make sure redirection works, too.
my $exit = eval { run "$perl output.pl > $tmp" };
is $@, "", "Should have no error from run with redirection";
is $exit, 0, "Should have exit 0 from run with redirection";
is $slurp->(), "Hello\nGoodbye\n", "Should have redirected text run";

$exit = eval { system "$perl output.pl > $tmp" };
is $@, "", "Should have no error from systemx with redirection";
is $exit, 0, "Should have exit 0 from systemx with redirection";
is $slurp->(), "Hello\nGoodbye\n", "Should have redirected text systemx";

# And single-string capture.
my $output = eval { capture "$perl output.pl" };
is $@, "", "Should have no error from single-string capture";
is $output, "Hello\nGoodbye\n", "Should have output from capture";
