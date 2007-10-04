# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.
require 'puppet/provider/nameservice/netinfo'

Puppet::Type.type(:group).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo do
    desc "Group management using NetInfo."
    commands :nireport => "nireport", :niutil => "niutil"

    defaultfor :operatingsystem => :darwin
end

