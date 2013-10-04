require 'puppet/util/adsi'

Puppet::Type.type(:group).provide :windows_adsi do
  desc "Local group management for Windows. Nested groups are not supported."

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
    Puppet::Util::Windows::Security.name_to_sid(@resource[:name])
  end

  def gid=(value)
    fail "gid is read-only"
  end

  def self.instances
    Puppet::Util::ADSI::Group.map { |g| new(:ensure => :present, :name => g.name) }
  end
end
