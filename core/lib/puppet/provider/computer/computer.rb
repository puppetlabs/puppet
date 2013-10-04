require 'puppet/provider/nameservice/directoryservice'

Puppet::Type.type(:computer).provide :directoryservice, :parent => Puppet::Provider::NameService::DirectoryService do
  desc "Computer object management using DirectoryService on OS X.
  Note that these are distinctly different kinds of objects to 'hosts',
  as they require a MAC address and can have all sorts of policy attached to
  them.

  This provider only manages Computer objects in the local directory service
  domain, not in remote directories.

  If you wish to manage /etc/hosts on Mac OS X, then simply use the host
  type as per other platforms."

  confine :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # hurray for abstraction. The nameservice directoryservice provider can
  # handle everything we need. super.
end
