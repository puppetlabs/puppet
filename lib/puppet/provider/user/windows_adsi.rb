require 'puppet/util/windows'

Puppet::Type.type(:user).provide :windows_adsi do
  desc "Local user management for Windows."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_homedir, :manages_passwords

  def user
    @user ||= Puppet::Util::Windows::ADSI::User.new(@resource[:name])
  end

  def groups
    user.groups.join(',')
  end

  def groups=(groups)
    user.set_groups(groups, @resource[:membership] == :minimum)
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
  end

  # Only flush if we created or modified a user, not deleted
  def flush
    @user.commit if @user
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
    user.password_is?( @resource[:password] ) ? @resource[:password] : :absent
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
