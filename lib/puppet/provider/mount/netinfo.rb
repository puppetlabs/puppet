# Manage NetInfo POSIX objects.  Probably only used on OS X, but I suppose
# it could be used elsewhere.
require 'puppet/provider/nameservice/netinfo'
require 'puppet/provider/mount'

# Puppet::Type.type(:mount).provide :netinfo, :parent => Puppet::Provider::NameService::NetInfo do
#     include Puppet::Provider::Mount
#     desc "Mount management in NetInfo.  This provider is highly experimental and is known
#         not to work currently."
#     commands :nireport => "nireport", :niutil => "niutil"
#     commands :mountcmd => "mount", :umount => "umount", :df => "df"
#
#     options :device, :key => "name"
#     options :name, :key => "dir"
#     options :dump, :key => "dump_freq"
#     options :pass, :key => "passno"
#     options :fstype, :key => "vfstype"
#     options :options, :key => "opts"
#
#     defaultfor :operatingsystem => :darwin
#
#     def initialize(resource)
#         warning "The NetInfo mount provider is highly experimental.  Use at your own risk."
#         super
#     end
#
#     def mount
#         cmd = []
#         if opts = @resource.should(:options)
#             cmd << opts
#         end
#         cmd << @resource.should(:device)
#         cmd << @resource[:name]
#         mountcmd cmd
#     end
# end

