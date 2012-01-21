require 'puppet/util/adsi'

Puppet::Type.type(:group).provide :windows_adsi do
  desc "Group management for Windows"

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_members

  def group
    @group ||= Puppet::Util::ADSI::Group.new(@resource[:name])
  end

  def members
    group.members
  end

  def members=(members)
    group.set_members(members)
  end

  def create
    @group = Puppet::Util::ADSI::Group.create(@resource[:name])
    @group.commit

    self.members = @resource[:members]
  end

  def exists?
    Puppet::Util::ADSI::Group.exists?(@resource[:name])
  end

  def delete
    Puppet::Util::ADSI::Group.delete(@resource[:name])
  end

  # Only flush if we created or modified a group, not deleted
  def flush
    @group.commit if @group
  end

  def gid
    Puppet::Util::ADSI.sid_for_account(@resource[:name])
  end

  def gid=(value)
    fail "gid is read-only"
  end

  def self.instances
    Puppet::Util::ADSI::Group.map { |g| new(:ensure => :present, :name => g.name) }
  end
end
