require 'puppet/util/windows'

Puppet::Type.type(:user).provide :windows_adsi do
  desc "Local user management for Windows."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_homedir, :manages_passwords

  def initialize(value={})
    super(value)
    @deleted = false
  end

  def user
    @user ||= Puppet::Util::Windows::ADSI::User.new(@resource[:name])
  end

  def groups
    @groups ||= Puppet::Util::Windows::ADSI::Group.name_sid_hash(user.groups)
    @groups.keys
  end

  def groups=(groups)
    user.set_groups(groups, @resource[:membership] == :minimum)
  end

  def groups_insync?(current, should)
    return false unless current

    # By comparing account SIDs we don't have to worry about case
    # sensitivity, or canonicalization of account names.

    # Cannot use munge of the group property to canonicalize @should
    # since the default array_matching comparison is not commutative

    # dupes automatically weeded out when hashes built
    current_groups = Puppet::Util::Windows::ADSI::Group.name_sid_hash(current)
    specified_groups = Puppet::Util::Windows::ADSI::Group.name_sid_hash(should)

    current_sids = current_groups.keys.to_a
    specified_sids = specified_groups.keys.to_a

    if @resource[:membership] == :inclusive
      current_sids.sort == specified_sids.sort
    else
      (specified_sids & current_sids) == specified_sids
    end
  end

  def groups_to_s(groups)
    return '' if groups.nil? || !groups.kind_of?(Array)
    groups = groups.map do |group_name|
      sid = Puppet::Util::Windows::SID.name_to_sid_object(group_name)
      if sid.account =~ /\\/
        account, _ = Puppet::Util::Windows::ADSI::Group.parse_name(sid.account)
      else
        account = sid.account
      end
      resource.debug("#{sid.domain}\\#{account} (#{sid.sid})")
      "#{sid.domain}\\#{account}"
    end
    return groups.join(',')
  end

  def create
    @user = Puppet::Util::Windows::ADSI::User.create(@resource[:name])
    @user.password = @resource[:password]
    @user.commit

    [:comment, :home, :groups].each do |prop|
      send("#{prop}=", @resource[prop]) if @resource[prop]
    end

    if @resource.managehome?
      Puppet::Util::Windows::User.load_profile(@resource[:name], @resource[:password])
    end
  end

  def exists?
    Puppet::Util::Windows::ADSI::User.exists?(@resource[:name])
  end

  def delete
    # lookup sid before we delete account
    sid = uid if @resource.managehome?

    Puppet::Util::Windows::ADSI::User.delete(@resource[:name])

    if sid
      Puppet::Util::Windows::ADSI::UserProfile.delete(sid)
    end

    @deleted = true
  end

  # Only flush if we created or modified a user, not deleted
  def flush
    @user.commit if @user && !@deleted
  end

  def comment
    user['Description']
  end

  def comment=(value)
    user['Description'] = value
  end

  def home
    user['HomeDirectory']
  end

  def home=(value)
    user['HomeDirectory'] = value
  end

  def password
    # avoid a LogonUserW style password check when the resource is not yet
    # populated with a password (as is the case with `puppet resource user`)
    return nil if @resource[:password].nil? || @resource[:password] == ''
    user.password_is?( @resource[:password] ) ? @resource[:password] : nil
  end

  def password=(value)
    user.password = value
  end

  def uid
    Puppet::Util::Windows::SID.name_to_sid(@resource[:name])
  end

  def uid=(value)
    fail "uid is read-only"
  end

  [:gid, :shell].each do |prop|
    define_method(prop) { nil }
    define_method("#{prop}=") do |v|
      fail "No support for managing property #{prop} of user #{@resource[:name]} on Windows"
    end
  end

  def self.instances
    Puppet::Util::Windows::ADSI::User.map { |u| new(:ensure => :present, :name => u.name) }
  end
end
