require 'puppet/provider/nameservice/objectadd'

Puppet::Type.type(:user).provide :useradd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "User management via `useradd` and its ilk.  Note that you will need to install the `Shadow Password` Ruby library often known as ruby-libshadow to manage user passwords."

  commands :add => "useradd", :delete => "userdel", :modify => "usermod", :password => "chage"

  options :home, :flag => "-d", :method => :dir
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :password_min_age, :flag => "-m"
  options :password_max_age, :flag => "-M"

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :groups, "Groups must be comma-separated" do |value|
    value !~ /\s/
  end

  has_features :manages_homedir, :allows_duplicates, :manages_expiry, :system_users

  has_features :manages_passwords, :manages_password_age if Puppet.features.libshadow?

  def check_allow_dup
    @resource.allowdupe? ? ["-o"] : []
  end

  def check_manage_home
    cmd = []
    if @resource.managehome?
      cmd << "-m"
    elsif %w{Fedora RedHat CentOS OEL OVS}.include?(Facter.value("operatingsystem"))
      cmd << "-M"
    end
    cmd
  end

  def check_manage_expiry
    cmd = []
    if @resource[:expiry]
      cmd << "-e #{@resource[:expiry]}"
    end

    cmd
  end

  def check_system_users
    @resource.system? ? ["-r"] : []
  end

  def add_properties
    cmd = []
    Puppet::Type.type(:user).validproperties.each do |property|
      next if property == :ensure
      next if property.to_s =~ /password_.+_age/
      # the value needs to be quoted, mostly because -c might
      # have spaces in it
      if value = @resource.should(property) and value != ""
        cmd << flag(property) << value
      end
    end
    cmd
  end

  def addcmd
    cmd = [command(:add)]
    cmd += add_properties
    cmd += check_allow_dup
    cmd += check_manage_home
    cmd += check_manage_expiry
    cmd += check_system_users
    cmd << @resource[:name]
  end

  def passcmd
    age_limits = [:password_min_age, :password_max_age].select { |property| @resource.should(property) }
    if age_limits.empty?
      nil
    else
      [command(:password),age_limits.collect { |property| [flag(property), @resource.should(property)]}, @resource[:name]].flatten
    end
  end

  def password_min_age
    if Puppet.features.libshadow?
      if ent = Shadow::Passwd.getspnam(@resource.name)
        return ent.sp_min
      end
    end
    :absent
  end

  def password_max_age
    if Puppet.features.libshadow?
      if ent = Shadow::Passwd.getspnam(@resource.name)
        return ent.sp_max
      end
    end
    :absent
  end

  # Retrieve the password using the Shadow Password library
  def password
    if Puppet.features.libshadow?
      if ent = Shadow::Passwd.getspnam(@resource.name)
        return ent.sp_pwdp
      end
    end
    :absent
  end
end

