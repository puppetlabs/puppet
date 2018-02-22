require 'puppet/provider/nameservice/objectadd'
require 'puppet/util/libuser'

Puppet::Type.type(:group).provide :groupadd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "Group management via `groupadd` and its ilk. The default for most platforms.

  "

  commands :add => "groupadd", :delete => "groupdel", :modify => "groupmod"

  has_feature :system_groups unless %w{HP-UX Solaris}.include? Facter.value(:operatingsystem)

  verify :gid, _("GID must be an integer") do |value|
    value.is_a? Integer
  end

  optional_commands :localadd => "lgroupadd", :localdelete => "lgroupdel", :localmodify => "lgroupmod"

  has_feature :libuser if Puppet.features.libuser?

  def exists?
    return !!localgid if @resource.forcelocal?
    super
  end

  def gid
    return localgid if @resource.forcelocal?
    get(:gid)
  end

  def findgroup(key, value)
    group_file = "/etc/group"
    group_keys = ['group_name', 'password', 'gid', 'user_list']
    index = group_keys.index(key)
    File.open(group_file) do |f|
      f.each_line do |line|
         group = line.split(":")
         if group[index] == value
             f.close
             return group
         end
      end
    end
    false
  end

  def localgid
    group = findgroup('group_name', resource[:name])
    return group[2] if group
    false
  end

  def check_allow_dup
    # We have to manually check for duplicates when using libuser
    # because by default duplicates are allowed.  This check is
    # to ensure consistent behaviour of the useradd provider when
    # using both useradd and luseradd
    if not @resource.allowdupe? and @resource.forcelocal?
       if @resource.should(:gid) and findgroup('gid', @resource.should(:gid).to_s)
           raise(Puppet::Error, _("GID %{resource} already exists, use allowdupe to force group creation") % { resource: @resource.should(:gid).to_s })
       end
    elsif @resource.allowdupe? and not @resource.forcelocal?
       return ["-o"]
    end
    []
  end

  def addcmd
    if @resource.forcelocal?
      cmd = [command(:localadd)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:add)]
    end

    if gid = @resource.should(:gid)
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    end
    cmd += check_allow_dup
    cmd << "-r" if @resource.system? and self.class.system_groups?
    cmd << @resource[:name]
    cmd
  end

  def modifycmd(param, value)
    if @resource.forcelocal?
      cmd = [command(:localmodify)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:modify)]
    end
    cmd << flag(param) << value
    # TODO the group type only really manages gid, so there are currently no
    # tests for this behavior
    cmd += check_allow_dup if param == :gid
    cmd << @resource[:name]

    cmd
  end

  def deletecmd
    if @resource.forcelocal?
      @custom_environment = Puppet::Util::Libuser.getenv
      [command(:localdelete), @resource[:name]]
    else
      [command(:delete), @resource[:name]]
    end
  end
end
