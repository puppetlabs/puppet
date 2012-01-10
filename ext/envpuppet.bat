@echo off
REM
REM Execute puppet, rspec, etc from source
REM
REM Assumptions:
REM ============
REM  ruby is installed and in your PATH
REM  puppet and facter source in the same parent directory, likely mounted
REM  through vmware, e.g. z:\work\puppet
REM
REM Sample Usage:
REM =============
REM   envpuppet puppet --version
REM
REM   envpuppet rspec --tag ~fails_on_windows spec
REM
REM Jeff McCune <jeff@puppetlabs.com>
REM Josh Cooper <josh@puppetlabs.com>
REM

setlocal

set PUPPET_DIR=%~dp0..
set PUPPET_DIR=%PUPPET_DIR:\=/%
set FACTER_DIR=%PUPPET_DIR%/../facter

set PATH=%PUPPET_DIR%\bin;%FACTER_DIR%\bin;%PATH%
set RUBYLIB=%PUPPET_DIR%/lib;%FACTER_DIR%/lib

ruby -S %*
