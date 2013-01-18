require 'puppet/provider/nameservice/objectadd'
require 'puppet/util/libuser'

Puppet::Type.type(:group).provide :groupadd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "Group management via `groupadd` and its ilk. The default for most platforms.

  "

  commands :add => "groupadd", :delete => "groupdel", :modify => "groupmod"

  has_feature :system_groups unless %w{HP-UX Solaris}.include? Facter.value(:operatingsystem)

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  optional_commands :localadd => "lgroupadd"
  has_feature :libuser if Puppet.features.libuser?

  def exists?
    return !!localgid if @resource.forcelocal?
    super
  end

  def localgid
    group_file = "/etc/group"
    File.open(group_file) do |f|
      f.each_line do |line|
         group = line.split(":")
         if group[0] == resource[:name]
             f.close
             return group[2]
         end
      end
    end
    false
  end 

  def libuser_conf
    File.expand_path("../libuser.conf", __FILE__)
  end 

  def addcmd
    if @resource.forcelocal?
      Puppet::Util::Libuser.setupenv
      cmd = [command(:localadd)]
    else 
      cmd = [command(:add)]
    end

    if gid = @resource.should(:gid)
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    end
    cmd << "-o" if @resource.allowdupe? and ! @resource.forcelocal?
    cmd << "-r" if @resource.system? and self.class.system_groups?
    cmd << @resource[:name]
    cmd
  end
end
