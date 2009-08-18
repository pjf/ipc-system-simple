package IPC::System::Simple::Exception;

=head1 NAME

IPC::System::Simple::Exception - a simple exception class for ISS

=head1 SYNOPSIS

    use strict;
    use warnings;
    use IPC::System::Simple qw(systemx);

    eval { systemx(qw(ls -al /tmp)); }

    if( $@->started_ok ) {
        warn "ls started ok, but something else went wrong: $@";
    }
    else {
        warn "curiously, ls wouldn't even start up...\n";
    }

=cut

# PJF - Having now given the matter a little more thought, should we
# really call this an 'exception' class?  It's really a status, that can
# be thrown as an exception.

# JET - I did notice that.  It is sensible since it takes on both roles...
# is_success/exit_value don't really belong here if it's an exception class.

use strict;
use warnings;
use Carp;
use Config;
use overload '""' => "stringify", fallback=>1;

use constant ISSE_UNKNOWN   => 0;
use constant ISSE_SUCCESS   => 1;
use constant ISSE_FSTART    => 2;
use constant ISSE_FSIGNAL   => 3;
use constant ISSE_FINTERNAL => 4;
use constant ISSE_FBADEXIT  => 5;
use constant ISSE_FPLUMBING => 6;

my @Signal_from_number = split(' ', $Config{sig_name});

our %DEFAULTS = (
    type              => ISSE_UNKNOWN,
    started_ok        => 1,
    command           => "unknown",
    args              => ["<unknown>"],
    allowable_returns => [],
    format            => 'unknown error',
    fmt_args          => [],
);

# XXX: This works as long as there's one and only one importer.... must fix
my $USEDBY = "IPC::System::Simple";
sub import { $USEDBY = caller; return }

=head1 CONSTRUCTOR METHODS

=over

=cut

=item B<new>

The new method should rarely be called directly, choose instead from the many
C<fail_*> methods. It takes field name and value pairs as arguments.

=cut

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

        # PJF - As long as we recommend that end-users always use
        # ISS directly, then we may not need to check $USEDBY at all.

        # JET - I wish to get rid of USEBY, don't get me wrong, but it seems
        # like you want this package to know where the error really occured.  It
        # won't do for it to announce errors by file and line in Simple.pm, so I
        # wished to back up one more frame.
        #
        # We can't really go back a set number of frames because sometimes this
        # package also kills itself.  USEBY clearly has to go though.

        next if $package->isa($USEDBY);
        next if $package->isa($class);
        next if $package->isa(__PACKAGE__);
        next if $file =~ /^\(eval\s\d+\)$/;

        last;
    }

    # PJF - Gosh, we're using this in both ISSE and autodie, I'm
    # wondering if there's scope for this to be extracted into a
    # separate module?  If so, there's a discussion regarding dependencies
    # and core modules to be had (since autodie is core, which makes
    # deps bothersome).

    # JET - (Well, this *is* a copy of the autodie exception class.  Perhaps
    # this stuff isn't really even needed here.)

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

    return $this->set(@_);
}

=item B<fail_start>

When a child precess fails to start, choose this method to build an exception
object.  B<fail_start> expects L</errstr>.

=cut

sub fail_start {
    my $class = shift;
    my $this  = $class->new(@_,
        started_ok => undef,
        type       => ISSE_FSTART,
        format     => '"*C" failed to start: "%s"', # *C is the command
        fmt_args   => [qw(errstr)],
    );

    $this->_throw_usage_error_unless_set(qw(errstr));

    return $this;
}

=item B<fail_signal>

If a child process dies due to signal delivery, this method builds an exception
object appropriate for that death.  B<fail_signal> expects L</signal_number> and
L</coredump> to be set properly.

=cut

sub fail_signal {
    my $class = shift;
    my $this  = $class->new(@_,
        type     => ISSE_FSIGNAL,
        format   => '"*C" died to signal "%s" (%d)%s', # *C is the command
        fmt_args => [qw/signal_name() signal_number _corestr()/],
    );

    $this->_throw_usage_error_unless_set(qw(signal_number coredump));

    return $this;
}

=item B<fail_internal>

If a child process dies due to signal delivery, this method builds an exception
object appropriate for that death. B<fail_internal> expects L</errstr> to be
set.

=cut

sub fail_internal {
    my $class = shift;
    my $this  = $class->new(@_,
        type     => ISSE_FINTERNAL,
        format   => 'Internal error in *U: %s', # *U is the USEDBY pacakge name
        fmt_args => [qw/errstr/],
    );

    $this->_throw_usage_error_unless_set(qw(signal_number coredump));

    return $this;
}

=item B<fail_badexit>

If a child runs sucessfully, but returns an unexpected exit value, this is the
correct exception.  B<fail_badexit> expects L</exit_value> to be set.

=cut

sub fail_badexit {
    my $class = shift;
    my $this  = $class->new(@_,
        type     => ISSE_FBADEXIT,
        format   => '"*C" unexpectedly returned exit value %d', # *C is the command
        fmt_args => [qw(exit_value)],
    );

    $this->_throw_usage_error_unless_set(qw(exit_value));

    return $this;
}

=item B<fail_plumbing>

Internal errors relating to the popen() calls inside L<IPC::System::Simple>.
B<fail_plumbing> expects L</errstr> and also an extra L</internal_errstr>
value.

=cut

sub fail_plumbing {
    my $class = shift;
    my $this  = $class->new(@_,
        type     => ISSE_FPLUMBING,
        format   => 'Error in IPC::System::Simple plumbing: "%s" - "%s"',
        fmt_args => [qw(internal_errstr errorstr)],
    );

    $this->_throw_usage_error_unless_set(qw(errorstr internal_errstr));

    return $this;
}

=item B<success>

When everything goes really well, we still build an exception object.  However,
the object will test true when asked L</is_success>:

    print "hooray, it finished!\n" if $status->is_success();

B<success> requires the L</exit_value> of the process.


=cut

# PJF - I'm not sure success is the best name here, because an end user
# *may* call it by accident.  If we separated the construction class
# (which builds the objects) from the exception/status objects themselves,
# then this problem goes away.
#
# PJF - Alternatively, a single method for building that takes the type of
# success/error would solve this issue, and has the advantage that anyone
# who wants to subclass in the future can just override a single method.

# JET - I'm not particularly fond of the method name: success().  In fact, I
# imagined this might come up -- and never did come up with a suitable
# replacement.  The different constructors are mostly similar, but some do a
# couple extra things (fail_plumbing vs fail_start).  I was afraid of this:

#     sub huge {
#         ... new things ...
#         if( )
#         elsif( )
#         elsif( )
#         elsif( )
#         elsif( )
#         elsif( )
#
#         if( )
#         elsif( )
#         elsif( )
#         elsif( )
#         elsif( )
#         elsif( )
#     }

# JET - (continued) I also imagined subclassing to be not such a problem since
# it'd *generally* be adding another fail type, or subtracting one back out.  I
# can't help but wonder: will this really get subclassed very often anyway?
# Aside from extending ISS for an extra gizmo, I can't imagine it'd come up
# very often.

sub success {
    my $class = shift;
    my $this  = $class->new(@_, type=>ISSE_SUCCESS);

    $this->_throw_usage_error_unless_set(qw(exit_value));

    return $this;
}

sub _throw_usage_error_unless_set {
    my $this = shift;

    my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);

    my @e;
    for(@_) {
        unless( exists $this->{$_} ) {
            if( $subroutine =~ m/::fail_/ ) {
                $subroutine =~ s/.*:://;
                push @e, "\"$_\" is a required setting for $subroutine()";

            } else {
                push @e, "\"$_\" was an expected setting";
            }
        }
    }

    if( @e ) {
        if( @e > 1 ) {
            local $"="\n\t";
            $this->fail_internal(errstr=>"multiple errors:\n\t@e")->throw;

        } else {
            $this->fail_internal(errstr=>$e[0])->throw;
        }
    }

    return;
}

=back

=head1 ACTION METHODS

=over

=item B<set>

Used to set the various settings accepted by the L<constructors|/CONSTRUCTOR
METHODS> after the objects have been built.  See L</SETTINGS> for the list of 
settings and what happens when they're missing.

=cut

# PJF - This doesn't do any checks to see if the attributes set are
# sensible, or that the attributes aren't clobbering internal state
# that we don't want to make public.  Does it make sense to be changing
# attributes on the object after it's been created?

# JET - it did make sense to make the retro fit in Simple.pm easier and more
# readable.  I like the way it reads to set the command and args well after the
# crash has occured.  The other choice would be to modify nearly every function
# that *can* crash to suddenly know the command and args just so it can pass
# them in to the constructor.  Certainly an optoin, but I disliked the idea of
# carring around all those arguments.
#
# I liked having this set() function because it could later be fitted with
# sanity checks -- I didn't really see a need for them now, but imagined it'd
# come up in the future.

sub set {
    my ($this, %opts) = @_;

    if( my $ar = delete $opts{caa} ) {
        @opts{qw(command args allowable_returns)} = @$ar;
    }

    @$this{keys %opts} = values %opts;
    return $this
}

=item B<throw>

Basically just a shortcut for L<croak|Carp>.  This function makes the object
croak an error (delivering the object into L<$@|perlvar/$@__>).

=cut

# PJF - Should this be a die() instead of a croak()?  We've already gone
# to the effort of finding our caller at object construction, so we
# shouldn't need croak to do it again.

# JET - I don't see that it makes a huge difference.  Hopefully we're not
# crashing so often that the extra cycles make a difference.  But die is
# probably better.

sub throw {
    my $this = shift;

    croak $this;
}

=item B<stringify>

Normally, this turns the error into a human readable error string.  Howevever,
when the exception is a success object, it returns the program exit value
instead.

The objects are L<overloaded|overload> such that when evaluated as a string, or
numerically, the objects (or possibly L<$@|perlvar/$@__>) will return the result
of B<stringify> automatically.

=cut

# PJF - I'm not sure what the !?!?! represents.  I'm also not thrilled
# about this returning the exit value on success, since the method is
# 'stringify', and hence we'd expect a string to come back.
#
# PJF - I need to look at this subroutine more.

# JET - I have mixed feelings about this tragedy myself, so ... all input
# welcome.  In fact, the commit where I numberify from a stringify notes this
# conflict.  The !?!?!?! on the other hand represents that this exception wasn't
# built well and we don't really know what bad thing is happening.  It could
# maybe say "<internal error: error unknown or something>" and mean nearly the
# same thing.  Hopefully end users don't see either.  But if they did, they
# could at least have something curious to ack/grep with.

sub stringify {
    my $this = shift;

    return $this->exit_value if $this->is_success;

    my $error = sprintf($this->{format}, map {
            my $res;

            if( m/^(.+?)\(\)$/ ) { $res = eval {$this->$1()} || "!?!?!"  }
            else                 { $res = $this->{$_}        || "!?!?!"  }

            $res;

    } @{$this->{fmt_args}});

    my @c = ($this->{command}, @{$this->{args}});
    $error =~ s/\*C/@c/g;
    $error =~ s/\*U/$USEDBY/g;

    return $error . " at $this->{file} line $this->{line}";
}

=item B<is_success>

Returns true if the exception is a success result.

=cut

sub is_success {
    my $this = shift;

    return 1 if $this->{type} == ISSE_SUCCESS;
    return;
}

=back

=head1 QUERY METHODS

=over

=item B<exit_value>

Returns the exit value of the child process, assuming the child actually spawned successfully.

=item B<signal_number>

In the event of a signal death, this will return the number of that signal.

=item B<dumped_core>

Returns true if L<IPC::System::Simple> detected a segmentation fault.

=item B<started_ok>

Returns true if the child process spawned successfully (even if it resulted in an error after the fork).

=cut

sub exit_value    { return $_[0]->{exit_value}    }
sub signal_number { return $_[0]->{signal_number} }
sub dumped_core   { return $_[0]->{coredump}      }
sub started_ok    { return $_[0]->{started_ok}    }

=item B<signal_name>

Returns the name of the received signal (if applicable).

=cut

sub signal_name {
    my $this = shift;

    return ($Signal_from_number[$this->{signal_number}] || "UNKNOWN");
}

=item B<child_error>

The value of the L<$?|perlvar/$?__> after the child exit -- usually less helpful than the L</exit_value>.

=item B<command>

The command that was executed (or that failed to execute).

=item B<args>

The arguments to the command above (either as an array or an arrayref, caller's choice).

=item B<allowable_returns>

The array (or arrayref) of return values that are considered acceptable.

=item B<caller>

The function that was being executed when the exception occured (if it is possible to locate).

=item B<file>

The file where the exception was generated.

=item B<line>

The line in the L</file> where the exception was generated.

=item B<package>

The package where the error occured.

=item B<type>

A numeric type for the exception.  At this time, the constants are not
exported, but can still be used via the package name.  Those functions are:
C<ISSE_UNKNOWN>, C<ISSE_SUCCESS>, C<ISSE_FSTART>, C<ISSE_FSIGNA>, C<ISSE_FINTERNAL>,
C<ISSE_FBADEXIT>, and C<ISSE_FPLUMBING>.

=cut

sub child_error       { return $_[0]->{child_error} }
sub command           { return $_[0]->{command} }
sub args              { return (wantarray ? @{$_[0]->{args}} : $_[0]->{args}) }
sub allowable_returns { return (wantarray ? @{$_[0]->{allowable_returns}} : $_[0]->{allowable_returns}) }

sub file     { return $_[0]->{file}     }
sub line     { return $_[0]->{line}     }
sub package  { return $_[0]->{package}  } ## no critic
sub caller   { return $_[0]->{caller}   } ## no critic

sub type     { return $_[0]->{type} }

sub _corestr { return ($_[0]->{coredump} ? " and dumped core" : "") }

=back

=head1 EXCEPTION OPTIONS

These are the optoins passed to the constructors and to the set routine.

=over

=item B<command>

The command that was executed.

=item B<args>

The arguments to the command that was executed.

=item B<allowable_returns>

The returns that were considered acceptable at the time the command was executed.

=item B<caa>

A shortcut for specifying command, args, and allowable returns simultaneously.
The following calls result in the same exception object setup:

    IPC::System::Simple::Exception->fail_start(
        command=>$cmd, args=>\@args,
        allowable_returns=>[0], errstr=>"blarg!" );

    IPC::System::Simple::Exception->fail_start(
        caa=>[$cmd, \@args, [0]], errstr=>"blarg!" );

=item B<child_error>

Typically the value of the L<$?|perlvar/$?__> after a child exit.  This value
isn't as useful as the L</exit_value>.

=item B<exit_value>

This is the exit value after some processing.  It's easier to use than
L</child_error>, which is one of the main benefits of using
L<IPC::System::Simple> in the first place.

=item B<coredump>

Set this to true when there was a segmentation fault and is usually left unset
otherwise.

=item B<signal_number>

When the child processed received a signal death, that signal should be stored
here.

=item B<started_ok>

This is normally set by the non-new constructors, but it can be set to true
when the child process started ok and false otherwise.

=item B<format>

This is normally set by the non-new constructors, but can be set to a custom
error message.  The style is that of L<sprintf|perlfunc/sprintf> with some
special substitutions:

=over

=item B<*C>

B<*C> is replaced with the command and its arguments.

=item B<*U>

B<*U> is replaced by the name of the package that used the exception module.

=back

=item B<fmt_args>

This is normally set by the non-new constructors.  It is the arguments to the
format string.  They can be either options names or
L<IPC::System::Simple::Exception> method names.

=item B<type>

This is normally set by the non-new constructors.  It is the numeric type of
the exception.

=back

=cut

1;

=head1 AUTHOR

Paul Miller C<< <jettero@cpan.org> >> under the direction of Paul Fenwick

=head1 COPYRIGHT

Copyright 2009 Paul Miller -- released under the same terms as L<IPC::System::Simple>.

=head1 SEE ALSO

perl(1), L<IPC::System::Simple>
