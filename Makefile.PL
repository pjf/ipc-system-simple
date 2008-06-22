#!/usr/bin/perl -w
use strict;
use 5.006;
use constant WINDOWS => ($^O eq 'MSWin32');
use inc::Module::Install;

name(		'IPC-System-Simple');
all_from(	'lib/IPC/System/Simple.pm');

requires(	'Config'	=> 0);
requires(	'List::Util'	=> 0);
requires(	'Scalar::Util'	=> 0);
requires(	'Win32::Process'=> 0) if WINDOWS;
requires(	'File::Spec'	=> 0) if WINDOWS;

test_requires(	'Test'		=> 0);
test_requires(	'Test::More'	=> 0);
test_requires(	'File::Basename'=> 0);

resources(	repository	=> "http://github.com/pfenwick/ipc-system-simple/tree/master");
resources(	bugtracker	=> "http://rt.cpan.org/NoAuth/Bugs.html?Dist=IPC-System-Simple");
resources(	forum		=> "http://www.cpanforum.com/dist/IPC-System-Simple");
resources(	blog		=> "http://pjf.id.au/blog/toc.html?tag=ipc-system-simple");

WriteAll();

