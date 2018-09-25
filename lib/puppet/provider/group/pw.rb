require 'puppet/provider/nameservice/pw'

Puppet::Type.type(:group).provide :pw, :parent => Puppet::Provider::NameService::PW do
  desc "Group management via `pw` on FreeBSD and DragonFly BSD."

  commands :pw => "pw"
  has_features :manages_members

  defaultfor :operatingsystem => [:freebsd, :dragonfly]
  confine    :operatingsystem => [:freebsd, :dragonfly]

  options :members,
          :flag    => "-M",
          :method  => :mem,
          :unmunge => proc { |members| members.join(',') }

  verify :gid, _("GID must be an integer") do |value|
    value.is_a? Integer
  end

  def addcmd
    cmd = [command(:pw), "groupadd", @resource[:name]]

    if gid = @resource.should(:gid)
      unless gid == :absent
        cmd << flag(:gid) << gid
      end
    end

    if members = @resource.should(:members)
      unless members == :absent
        cmd << "-M" << members
      end
    end

    cmd << "-o" if @resource.allowdupe?

    cmd
  end

  def modifycmd(param, value)
    super(param, value)
  end
end

