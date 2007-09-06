use 5.006;
use constant WINDOWS => ($^O eq 'MSWin32');
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'IPC::System::Simple',
    VERSION_FROM      => 'lib/IPC/System/Simple.pm', # finds $VERSION
    PREREQ_PM         => (WINDOWS ? { 'Win32::Process' => 0 } : {} ),
    ($ExtUtils::MakeMaker::VERSION > 6.30 ?
      ( LICENSE           => 'perl' ) : ()
    ),
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/IPC/System/Simple.pm', # retrieve abstract from module
       AUTHOR         => 'Paul Fenwick <pjf@cpan.org>') : ()
    ),
);
