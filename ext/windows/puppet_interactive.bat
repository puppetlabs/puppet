@echo off
SETLOCAL
echo Running Puppet agent on demand ...
cd "%~dp0"
call puppet.bat agent --test %*
PAUSE
