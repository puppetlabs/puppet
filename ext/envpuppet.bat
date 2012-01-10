@echo off
SETLOCAL

REM net use Z: "\\vmware-host\Shared Folders" /persistent:yes

SET RUBYLIB=Z:/vagrant/src/facter/lib;Z:/vagrant/src/puppet/lib;%RUBYLIB%
SET PATH=Z:/vagrant/src/facter/bin;Z:/vagrant/src/puppet/bin;%PATH%

ruby -S %*

