require_relative '../../../puppet/provider/nameservice/pw'
require 'open3'

Puppet::Type.type(:user).provide :pw, :parent => Puppet::Provider::NameService::PW do
  desc "User management via `pw` on FreeBSD and DragonFly BSD."

  commands :pw => "pw"
  has_features :manages_homedir, :allows_duplicates, :manages_passwords, :manages_expiry, :manages_shell, :system_users

  defaultfor :operatingsystem => [:freebsd, :dragonfly]
  confine    :operatingsystem => [:freebsd, :dragonfly]

  options :home, :flag => "-d", :method => :dir
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :expiry, :method => :expire, :munge => proc { |value|
    value = '0000-00-00' if value == :absent
    value.split("-").reverse.join("-")
  }

  MAX_SYSTEM_UID = 999
  MIN_SYSTEM_UID = 100

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :groups, "Groups must be comma-separated" do |value|
    value !~ /\s/
  end

  def addcmd
    cmd = [command(:pw), "useradd", @resource[:name]]
    @resource.class.validproperties.each do |property|
      next if property == :ensure or property == :password
      value = @resource.should(property)
      if value and value != ""
        cmd << flag(property) << munge(property,value)
      end
    end
    cmd << flag(:uid) << next_system_uid if @resource.system? && !@resource.should(:uid)

    cmd << "-o" if @resource.allowdupe?
    cmd << "-m" if @resource.managehome?
    cmd
  end

  def next_system_uid
    used_uid = []
    Etc.passwd { |user| used_uid << user.uid if (MIN_SYSTEM_UID..MAX_SYSTEM_UID).cover?(user.uid) }

    uid = MAX_SYSTEM_UID
    uid -= 1 while used_uid.include?(uid) && uid >= MIN_SYSTEM_UID
    raise Puppet::Error.new("No free uid available for user resource '#{resource[:name]}'") if uid < MIN_SYSTEM_UID

    return uid
  end

  def modifycmd(param, value)
    if param == :expiry
      # FreeBSD uses DD-MM-YYYY rather than YYYY-MM-DD
      value = value.split("-").reverse.join("-")
    end
    cmd = super(param, value)
    cmd << "-m" if @resource.managehome?
    cmd
  end

  def deletecmd
    cmd = super
    cmd << "-r" if @resource.managehome?
    cmd
  end

  def create
    super

    # Set the password after create if given
    self.password = @resource[:password] if @resource[:password]
  end

  # use pw to update password hash
  def password=(cryptopw)
    Puppet.debug "change password for user '#{@resource[:name]}' method called with hash [redacted]"
    stdin, _, _ = Open3.popen3("pw user mod #{@resource[:name]} -H 0")
    stdin.puts(cryptopw)
    stdin.close
    Puppet.debug "finished password for user '#{@resource[:name]}' method called with hash [redacted]"
  end

  # get password from /etc/master.passwd
  def password
    Puppet.debug "checking password for user '#{@resource[:name]}' method called"
    current_passline = `getent passwd #{@resource[:name]}`
    current_password = current_passline.chomp.split(':')[1] if current_passline
    Puppet.debug "finished password for user '#{@resource[:name]}' method called : [redacted]"
    current_password
  end

  def has_sensitive_data?(property = nil)
    #Check for sensitive values?
    properties = property ? [property] : Puppet::Type.type(:user).validproperties
    properties.any? do |prop|
      p = @resource.parameter(prop)
      p && p.respond_to?(:is_sensitive) && p.is_sensitive
    end
  end

  # Get expiry from system and convert to Puppet-style date
  def expiry
    expiry = self.get(:expiry)
    expiry = :absent if expiry == 0

    if expiry != :absent
      t = Time.at(expiry)
      expiry = "%4d-%02d-%02d" % [t.year, t.month, t.mday]
    end

    expiry
  end
end

