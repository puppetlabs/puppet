# Manage NetInfo POSIX objects.
#
# This provider has been deprecated. You should be using the directoryservice
# nameservice provider instead.

require 'puppet/provider/nameservice/netinfo'

Puppet::Type.type(:group).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo do
    desc "Group management using NetInfo."
    commands :nireport => "nireport", :niutil => "niutil"

end

