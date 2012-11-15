@echo off
SETLOCAL

call "%~dp0..\bin\environment.bat" %0 %*

rubyw -rubygems "%~dp0daemon.rb" %*