@echo off
SETLOCAL
SET PL_BASEDIR=%~dp0..

REM Avoid the nasty \..\ littering the paths.
SET PL_BASEDIR=%PL_BASEDIR:\bin\..=%

SET PUPPET_DIR=%PL_BASEDIR%\puppet
SET FACTER_DIR=%PL_BASEDIR%\facter

SET PATH=%PUPPET_DIR%\bin;%FACTER_DIR%\bin;%PL_BASEDIR%\bin;%PL_BASEDIR%\sys\ruby\bin;%PATH%
SET RUBYLIB=%PUPPET_DIR%\lib;%FACTER_DIR%\lib;%RUBYLIB%
SET RUBYLIB=%RUBYLIB:\=/%

REM We always want to load Puppet facts which have been plugin synced from
REM the Puppet Master
ruby -S -- %0 --puppet %*
