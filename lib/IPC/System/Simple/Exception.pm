package IPC::System::Simple::Exception;

use strict;
use warnings;
use Config;
use overload '""' => "stringify";

use constant ISSE_SUCCESS   => 1;
use constant ISSE_FSTART    => 2;
use constant ISSE_FSIGNAL   => 3;
use constant ISSE_FINTERNAL => 4;
use constant ISSE_FBADEXIT  => 5;

my @Signal_from_number = split(' ', $Config{sig_name});

our %DEFAULTS = (
    exit_value        => -1,
    signal_number     => -1,
    started_ok        => 1,
    command           => "unknown",
    function          => "unknown",
    args              => [],
    allowable_returns => [0],
);

my $USEDBY = "IPC::System::Simple";
sub import { $USEDBY = caller }

sub new {
    my $class = shift;
    my $this = bless {%DEFAULTS}, $class;

    my ($package, $file, $line, $sub);

    my $depth = 0;
    while (1) {
        $depth++;
        ($package, $file, $line, $sub) = CORE::caller($depth);

        # Skip up the call stack until we find something outside
        # of the caller, $class or eval space

        next if $package->isa($USEDBY);
        next if $package->isa($class);
        next if $package->isa(__PACKAGE__);
        next if $file =~ /^\(eval\s\d+\)$/;

        last;
    }

    # We now have everything correct, *except* for our subroutine
    # name.  If it's __ANON__ or (eval), then we need to keep on
    # digging deeper into our stack to find the real name.  However we
    # don't update our other information, since that will be correct
    # for our current exception.

    my $first_guess_subroutine = $sub;
    while (defined $sub and $sub =~ /^\(eval\)$|::__ANON__$/) {
        $depth++;
        $sub = (CORE::caller($depth))[3];
    }

    # If we end up falling out the bottom of our stack, then our
    # __ANON__ guess is the best we can get.  This includes situations
    # where we were called from the top level of a program.

    if (not defined $sub) {
        $sub = $first_guess_subroutine;
    }

    $this->{package}  = $package;
    $this->{file}     = $file;
    $this->{line}     = $line;
    $this->{caller}   = $sub;

    warn "DEBUG(usedby: $USEDBY, package: $package, file: $file, line: $line)";

    $this->set(@_);
}

sub fail_start {
    my $class = shift;
    my $this  = $class->new(@_, started_ok=>undef);

    $this;
}

sub fail_signal {
    my $class = shift;
    my $this  = $class->new(@_);

    $this;
}

sub fail_internal {
    my $class = shift;
    my $this  = $class->new(@_);

    $this;
}

sub fail_badexit {
    my $class = shift;
    my $this  = $class->new(@_);

    $this;
}

sub success {
    my $class = shift;
    my $this  = $class->new(@_);

    $this;
}

sub set {
    my ($this, %opts) = @_;

    @$this{keys %opts} = values %opts;
    $this
}

sub throw {
    my $this = shift;

    croak $this;
}

sub stringify {
    "blah blah blah"
}

sub is_success {
    my $this = shift;

    return 1 if $this->{type} == ISSE_SUCCESS;
    return;
}

sub exit_value    { $_[0]->{exit_value}    }
sub signal_number { $_[0]->{signal_number} }
sub dumped_core   { $_[0]->{coredump}      }
sub started_ok    { $_[0]->{started_ok}    }

sub signal_name {
    my $this = shift;

    $Signal_from_number[$this->{signal_nmber}] || "UNKNOWN";
}

sub child_error       { $_[0]->{child_error} }
sub command           { $_[0]->{command} }
sub args              { wantarray ? @{$_[0]->{args}} : $_[0]->{args} }
sub allowable_returns { wantarray ? @{$_[0]->{allowable_returns}} : $_[0]->{allowable_returns} }

sub function { $_[0]->{function} }
sub file     { $_[0]->{file}     }
sub package  { $_[0]->{package}  }
sub caller   { $_[0]->{caller}   }
