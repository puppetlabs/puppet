@echo off
SETLOCAL

call "%~dp0..\bin\environment.bat" %0 %*

rubyw "%~dp0daemon.rb" %*