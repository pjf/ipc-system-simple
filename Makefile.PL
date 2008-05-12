#!/usr/bin/perl -w
use strict;
use 5.006;
use constant WINDOWS => ($^O eq 'MSWin32');
use inc::Module::Install;

name		'IPC-System-Simple';
all_from	'lib/IPC/System/Simple.pm';

requires	'Config'	=> 0;
requires	'List::Util'	=> 0;
requires	'Scalar::Util'	=> 0;
requires	'Win32::Process'=> 0 if WINDOWS;
requires	'File::Spec'	=> 0 if WINDOWS;

test_requires	'Test'		=> 0;
test_requires	'Test::More'	=> 0;
test_requires	'File::Basename'=> 0;

WriteAll;

__END__

# For extra cpants points we'd like to add extra things
# to our META.yml.  MakeMaker 6.44 provides an experimental
# feature that does this, but apparently it will change in 6.45;
# hence the exact version check.

my @extra_terms = ();

if ($ExtUtils::MakeMaker::VERSION == 6.44) {
	push(@extra_terms, EXTRA_META => <<'META',
resources:
    license:    http://dev.perl.org/licenses/
    bugtracker: http://rt.cpan.org/NoAuth/Bugs.html?Dist=IPC-System-Simple
keywords:
    - system
    - run
    - capture
    - qx
    - backticks
    - exceptions
META
);
}

WriteMakefile(
    NAME              => 'IPC::System::Simple',
    VERSION_FROM      => 'lib/IPC/System/Simple.pm', # finds $VERSION
    PREREQ_PM         => {
	'Config'      => 0,
	'List::Util'  => 0,
	'Scalar::Util'=> 0,
	(WINDOWS ? ( 'Win32::Process' => 0 ) : ())
    },
    ($ExtUtils::MakeMaker::VERSION > 6.30 ?
      ( LICENSE           => 'perl' ) : ()
    ),
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/IPC/System/Simple.pm', # retrieve abstract from module
       AUTHOR         => 'Paul Fenwick <pjf@cpan.org>') : ()
    ),
    @extra_terms,
);
