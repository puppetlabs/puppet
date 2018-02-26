require 'puppet/util/windows'

Puppet::Type.type(:group).provide :windows_adsi do
  desc "Local group management for Windows. Group members can be both users and groups.
    Additionally, local groups can contain domain users."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_members

  def initialize(value={})
    super(value)
    @deleted = false
  end

  def members_insync?(current, should)
    return false unless current

    # By comparing account SIDs we don't have to worry about case
    # sensitivity, or canonicalization of account names.

    # Cannot use munge of the group property to canonicalize @should
    # since the default array_matching comparison is not commutative

    # dupes automatically weeded out when hashes built
    current_users = Puppet::Util::Windows::ADSI::Group.name_sid_hash(current)
    specified_users = Puppet::Util::Windows::ADSI::Group.name_sid_hash(should)

    current_sids = current_users.keys.to_a
    specified_sids = specified_users.keys.to_a

    if @resource[:auth_membership]
      current_sids.sort == specified_sids.sort
    else
      (specified_sids & current_sids) == specified_sids
    end
  end

  def members_to_s(users)
    return '' if users.nil? or !users.kind_of?(Array)
    users = users.map do |user_name|
      sid = Puppet::Util::Windows::SID.name_to_sid_object(user_name)
      if !sid
        resource.debug("#{user_name} (unresolvable to SID)")
        next user_name
      end

      if sid.account =~ /\\/
        account, _ = Puppet::Util::Windows::ADSI::User.parse_name(sid.account)
      else
        account = sid.account
      end
      resource.debug("#{sid.domain}\\#{account} (#{sid.sid})")
      "#{sid.domain}\\#{account}"
    end
    return users.join(',')
  end

  def member_valid?(user_name)
    ! Puppet::Util::Windows::SID.name_to_sid_object(user_name).nil?
  end

  def group
    @group ||= Puppet::Util::Windows::ADSI::Group.new(@resource[:name])
  end

  def members
    group.members
  end

  def members=(members)
    group.set_members(members, @resource[:auth_membership])
  end

  def create
    @group = Puppet::Util::Windows::ADSI::Group.create(@resource[:name])
    @group.commit

    self.members = @resource[:members]
  end

  def exists?
    Puppet::Util::Windows::ADSI::Group.exists?(@resource[:name])
  end

  def delete
    Puppet::Util::Windows::ADSI::Group.delete(@resource[:name])

    @deleted = true
  end

  # Only flush if we created or modified a group, not deleted
  def flush
    @group.commit if @group && !@deleted
  end

  def gid
    Puppet::Util::Windows::SID.name_to_sid(@resource[:name])
  end

  def gid=(value)
    fail "gid is read-only"
  end

  def self.instances
    Puppet::Util::Windows::ADSI::Group.map { |g| new(:ensure => :present, :name => g.name) }
  end
end
