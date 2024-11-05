require_relative '../../../puppet/provider/nameservice/objectadd'
require_relative '../../../puppet/util/libuser'

Puppet::Type.type(:group).provide :groupadd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "Group management via `groupadd` and its ilk. The default for most platforms.

 To use the `forcelocal` parameter, you need to install the `libuser` package (providing
  `/usr/sbin/lgroupadd` and `/usr/sbin/luseradd`)."

  commands :add => "groupadd", :delete => "groupdel", :modify => "groupmod"

  has_feature :system_groups unless %w{HP-UX Solaris}.include? Puppet.runtime[:facter].value('os.name')

  verify :gid, _("GID must be an integer") do |value|
    value.is_a? Integer
  end

  optional_commands :localadd => "lgroupadd", :localdelete => "lgroupdel", :localmodify => "lgroupmod", :purgemember => "usermod"

  has_feature :manages_local_users_and_groups if Puppet.features.libuser?
  has_feature :manages_members if Puppet.features.libuser? ||
                                  (Puppet.runtime[:facter].value('os.name') == "Fedora" &&
                                  Puppet.runtime[:facter].value('os.release.major').to_i >= 40)

  # Libuser's modify command 'lgroupmod' requires '-M' flag for member additions.
  # 'groupmod' command requires the '-aU' flags for it.
  if Puppet.features.libuser?
    options :members, :flag => '-M', :method => :mem
  else
    options :members, :flag => '-aU', :method => :mem
  end

  def exists?
    return !!localgid if @resource.forcelocal?
    super
  end

  def gid
    return localgid if @resource.forcelocal?
    get(:gid)
  end

  def localgid
    group = findgroup(:group_name, resource[:name])
    return group[:gid] if group
    false
  end

  def check_allow_dup
    # We have to manually check for duplicates when using libuser
    # because by default duplicates are allowed.  This check is
    # to ensure consistent behaviour of the useradd provider when
    # using both useradd and luseradd
    if not @resource.allowdupe? and @resource.forcelocal?
       if @resource.should(:gid) and findgroup(:gid, @resource.should(:gid).to_s)
           raise(Puppet::Error, _("GID %{resource} already exists, use allowdupe to force group creation") % { resource: @resource.should(:gid).to_s })
       end
    elsif @resource.allowdupe? and not @resource.forcelocal?
       return ["-o"]
    end
    []
  end

  def create
    super
    set(:members, @resource[:members]) if @resource[:members]
  end

  def addcmd
    # The localadd command (lgroupadd) must only be called when libuser is supported.
    if Puppet.features.libuser? && @resource.forcelocal?
      cmd = [command(:localadd)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:add)]
    end

    gid = @resource.should(:gid)
    if gid
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    end
    cmd += check_allow_dup
    cmd << "-r" if @resource.system? and self.class.system_groups?
    cmd << @resource[:name]
    cmd
  end

  def validate_members(members)
    members.each do |member|
      member.split(',').each do |user|
        Etc.getpwnam(user.strip)
      end
    end
  end

  def modifycmd(param, value)
    # The localmodify command (lgroupmod) must only be called when libuser is supported.
    if Puppet.features.libuser? && (@resource.forcelocal? || @resource[:members])
      cmd = [command(:localmodify)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:modify)]
    end

    if param == :members
      validate_members(value)
      value = members_to_s(value)
      purge_members if @resource[:auth_membership] && !members.empty?
    end

    cmd << flag(param) << value
    # TODO the group type only really manages gid, so there are currently no
    # tests for this behavior
    cmd += check_allow_dup if param == :gid
    cmd << @resource[:name]

    cmd
  end

  def deletecmd
    # The localdelete command (lgroupdel) must only be called when libuser is supported.
    if Puppet.features.libuser? && @resource.forcelocal?
      @custom_environment = Puppet::Util::Libuser.getenv
      [command(:localdelete), @resource[:name]]
    else
      [command(:delete), @resource[:name]]
    end
  end

  def members_insync?(current, should)
    current.uniq.sort == @resource.parameter(:members).actual_should(current, should)
  end

  def members_to_s(current)
    return '' if current.nil? || !current.kind_of?(Array)
    current.join(',')
  end

  def purge_members
    # The groupadd provider doesn't have the ability currently to remove members from a group, libuser does.
    # Use libuser's lgroupmod command to achieve purging members if libuser is supported.
    # Otherwise use the 'usermod' command.
    if Puppet.features.libuser?
      localmodify('-m', members_to_s(members), @resource.name)
    else
      members.each do |member|
        purgemember('-rG', @resource.name, member)
      end
    end
  end

  private

  def findgroup(key, value)
    group_file = '/etc/group'
    group_keys = [:group_name, :password, :gid, :user_list]

    unless @groups
      unless Puppet::FileSystem.exist?(group_file)
        raise Puppet::Error.new("Forcelocal set for group resource '#{resource[:name]}', but #{group_file} does not exist")
      end

      @groups = []
      Puppet::FileSystem.each_line(group_file) do |line|
        group = line.chomp.split(':')
        @groups << Hash[group_keys.zip(group)]
      end
    end

    @groups.find { |param| param[key] == value } || false
  end
end
