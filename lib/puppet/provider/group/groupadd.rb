require 'puppet/provider/nameservice/objectadd'

Puppet::Type.type(:group).provide :groupadd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "Group management via `groupadd` and its ilk.

  The default for most platforms

  "

  commands :add => "groupadd", :delete => "groupdel", :modify => "groupmod"

  has_feature :system_groups

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  def addcmd
    cmd = [command(:add)]
    if gid = @resource.should(:gid)
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    end
    cmd << "-o" if @resource.allowdupe?
    cmd << "-r" if @resource.system?
    cmd << @resource[:name]

    cmd
  end
end

