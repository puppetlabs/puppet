require_relative '../../../puppet/provider/nameservice/pw'

Puppet::Type.type(:group).provide :pw, :parent => Puppet::Provider::NameService::PW do
  desc "Group management via `pw` on FreeBSD and DragonFly BSD."

  commands :pw => "pw"
  has_features :manages_members, :system_groups

  defaultfor :operatingsystem => [:freebsd, :dragonfly]
  confine    :operatingsystem => [:freebsd, :dragonfly]

  options :members, :flag => "-M", :method => :mem

  MAX_SYSTEM_GID = 999
  MIN_SYSTEM_GID = 100

  verify :gid, _("GID must be an integer") do |value|
    value.is_a? Integer
  end

  def addcmd
    cmd = [command(:pw), "groupadd", @resource[:name]]

    gid = @resource.should(:gid)
    if gid
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    elsif @resource.system?
      cmd << flag(:gid) << next_system_gid
    end

    members = @resource.should(:members)
    if members
      unless members == :absent
        if members.is_a?(Array)
          members = members.join(",")
        end
        cmd << "-M" << members
      end
    end

    cmd << "-o" if @resource.allowdupe?

    cmd
  end

  def next_system_gid
    used_gid = []
    Etc.group { |group| used_gid << group.gid if (MIN_SYSTEM_GID..MAX_SYSTEM_GID).cover?(group.gid) }

    gid = MAX_SYSTEM_GID
    gid -= 1 while used_gid.include?(gid) && gid >= MIN_SYSTEM_GID
    raise Puppet::Error.new("No free gid available for group resource '#{resource[:name]}'") if gid < MIN_SYSTEM_GID

    return gid
  end

  def modifycmd(param, value)
    # members may be an array, need a comma separated list
    if param == :members and value.is_a?(Array)
      value = value.join(",")
    end
    super(param, value)
  end
end

