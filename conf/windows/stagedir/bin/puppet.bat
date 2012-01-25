@echo off
SETLOCAL

REM This is the parent directory of the directory containing this script.
SET PL_BASEDIR=%~dp0..

REM Avoid the nasty \..\ littering the paths.
SET PL_BASEDIR=%PL_BASEDIR:\bin\..=%

SET PUPPET_DIR=%PL_BASEDIR%\puppet
SET FACTER_DIR=%PL_BASEDIR%\facter

SET PATH=%PUPPET_DIR%\bin;%FACTER_DIR%\bin;%PL_BASEDIR%\bin;%PL_BASEDIR%\sys\ruby\bin;%PATH%

REM Set the RUBY LOAD_PATH using the RUBYLIB environment variable
SET RUBYLIB=%PUPPET_DIR%\lib;%FACTER_DIR%\lib;%RUBYLIB%

REM Translate all slashes to / style to avoid issue #11930
SET RUBYLIB=%RUBYLIB:\=/%

REM %0 will be the subcommand, agent, apply, resource, etc...
REM %* will be the positional arguments passed to this script.
ruby -S -- %0 %*
