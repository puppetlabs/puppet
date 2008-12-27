# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.
require 'puppet/provider/nameservice/netinfo'

Puppet::Type.type(:host).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo,
    :netinfodir => "machines" do
    desc "Host management in NetInfo.

    This provider is highly experimental and is known not to work currently.

  "
    commands :nireport => "nireport", :niutil => "niutil"
    commands :mountcmd => "mount", :umount => "umount", :df => "df"

    options :ip, :key => "ip_address"

    defaultfor :operatingsystem => :darwin
end

