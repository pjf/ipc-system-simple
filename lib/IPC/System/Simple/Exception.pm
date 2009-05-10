
package IPC::System::Simple::Exception;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $this = bless {
    }, $class;

    $this->set(@_);
    $this;
}

sub fail_start {
    my $class = shift;
    my $this  = $class->new(@_);

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

    croak "blah blah blah";
}

