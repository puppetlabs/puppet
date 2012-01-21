require 'puppet/util/adsi'

Puppet::Type.type(:user).provide :windows_adsi do
  desc "User management for Windows."

  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  has_features :manages_homedir, :manages_passwords

  def user
    @user ||= Puppet::Util::ADSI::User.new(@resource[:name])
  end

  def groups
    user.groups.join(',')
  end

  def groups=(groups)
    user.set_groups(groups, @resource[:membership] == :minimum)
  end

  def create
    @user = Puppet::Util::ADSI::User.create(@resource[:name])
    @user.password = @resource[:password]
    @user.commit

    [:comment, :home, :groups].each do |prop|
      send("#{prop}=", @resource[prop]) if @resource[prop]
    end
  end

  def exists?
    Puppet::Util::ADSI::User.exists?(@resource[:name])
  end

  def delete
    Puppet::Util::ADSI::User.delete(@resource[:name])
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
    Puppet::Util::ADSI.sid_for_account(@resource[:name])
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
    Puppet::Util::ADSI::User.map { |u| new(:ensure => :present, :name => u.name) }
  end
end
