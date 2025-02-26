require 'puppet/provider/nameservice/objectadd'
require 'date'
require 'puppet/util/libuser'
require 'time'
require 'puppet/error'

Puppet::Type.type(:user).provide :useradd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "User management via `useradd` and its ilk.  Note that you will need to
    install Ruby's shadow password library (often known as `ruby-libshadow`)
    if you wish to manage user passwords."

  commands :add => "useradd", :delete => "userdel", :modify => "usermod", :password => "chage"

  options :home, :flag => "-d", :method => :dir
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :password_min_age, :flag => "-m", :method => :sp_min
  options :password_max_age, :flag => "-M", :method => :sp_max
  options :password, :method => :sp_pwdp
  options :expiry, :method => :sp_expire,
    :munge => proc { |value|
      if value == :absent
        ''
      else
        case Facter.value(:operatingsystem)
        when 'Solaris'
          # Solaris uses %m/%d/%Y for useradd/usermod
          expiry_year, expiry_month, expiry_day = value.split('-')
          [expiry_month, expiry_day, expiry_year].join('/')
        else
          value
        end
      end
    },
    :unmunge => proc { |value|
      if value == -1
        :absent
      else
        # Expiry is days after 1970-01-01
        (Date.new(1970,1,1) + value).strftime('%Y-%m-%d')
      end
    }

  optional_commands :localadd => "luseradd"
  has_feature :libuser if Puppet.features.libuser?

  def exists?
    return !!localuid if @resource.forcelocal?
    super
  end

  def uid
     return localuid if @resource.forcelocal?
     get(:uid)
  end

  def finduser(key, value)
    passwd_file = "/etc/passwd"
    passwd_keys = ['account', 'password', 'uid', 'gid', 'gecos', 'directory', 'shell']
    index = passwd_keys.index(key)
    File.open(passwd_file) do |f|
      f.each_line do |line|
         user = line.split(":")
         if user[index] == value
             f.close
             return user
         end
      end
    end
    false
  end

  def local_username
    finduser('uid', @resource.uid)
  end

  def localuid
    user = finduser('account', resource[:name])
    return user[2] if user
    false
  end

  def shell=(value)
    check_valid_shell
    set("shell", value)
  end

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :groups, "Groups must be comma-separated" do |value|
    value !~ /\s/
  end

  has_features :manages_homedir, :allows_duplicates, :manages_expiry
  has_features :system_users unless %w{HP-UX Solaris}.include? Facter.value(:operatingsystem)

  has_features :manages_passwords, :manages_password_age if Puppet.features.libshadow?
  has_features :manages_shell

  def check_allow_dup
    # We have to manually check for duplicates when using libuser
    # because by default duplicates are allowed.  This check is
    # to ensure consistent behaviour of the useradd provider when
    # using both useradd and luseradd
    if not @resource.allowdupe? and @resource.forcelocal?
       if @resource.should(:uid) and finduser('uid', @resource.should(:uid).to_s)
           raise(Puppet::Error, "UID #{@resource.should(:uid).to_s} already exists, use allowdupe to force user creation")
       end
    elsif @resource.allowdupe? and not @resource.forcelocal?
       return ["-o"]
    end
    []
  end

  def check_valid_shell
    unless File.exists?(@resource.should(:shell))
      raise(Puppet::Error, "Shell #{@resource.should(:shell)} must exist")
    end
    unless File.executable?(@resource.should(:shell).to_s)
      raise(Puppet::Error, "Shell #{@resource.should(:shell)} must be executable")
    end
  end

  def check_manage_home
    cmd = []
    if @resource.managehome? and not @resource.forcelocal?
      cmd << "-m"
    elsif not @resource.managehome? and Facter.value(:osfamily) == 'RedHat'
      cmd << "-M"
    end
    cmd
  end

  def check_manage_expiry
    cmd = []
    if @resource[:expiry] and not @resource.forcelocal?
      cmd << "-e #{@resource[:expiry]}"
    end

    cmd
  end

  def check_system_users
    if self.class.system_users? and resource.system?
      ["-r"]
    else
      []
    end
  end

  def add_properties
    cmd = []
    # validproperties is a list of properties in undefined order
    # sort them to have a predictable command line in tests
    Puppet::Type.type(:user).validproperties.sort.each do |property|
      next if property == :ensure
      next if property.to_s =~ /password_.+_age/
      next if property == :groups and @resource.forcelocal?
      next if property == :expiry and @resource.forcelocal?
      # the value needs to be quoted, mostly because -c might
      # have spaces in it
      if value = @resource.should(property) and value != ""
        cmd << flag(property) << munge(property, value)
      end
    end
    cmd
  end

  def addcmd
    if @resource.forcelocal?
      cmd = [command(:localadd)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:add)]
    end
    if not @resource.should(:gid) and Puppet::Util.gid(@resource[:name])
      cmd += ["-g", @resource[:name]]
    end
    cmd += add_properties
    cmd += check_allow_dup
    cmd += check_manage_home
    cmd += check_system_users
    cmd << @resource[:name]
  end

  def deletecmd
    cmd = [command(:delete)]
    cmd += @resource.managehome? ? ['-r'] : []
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

  [:expiry, :password_min_age, :password_max_age, :password].each do |shadow_property|
    define_method(shadow_property) do
      if Puppet.features.libshadow?
        if ent = Shadow::Passwd.getspnam(@resource.name)
          method = self.class.option(shadow_property, :method)
          return unmunge(shadow_property, ent.send(method))
        end
      end
      :absent
    end
  end

  def create
    if @resource[:shell]
      check_valid_shell
    end
     super
     if @resource.forcelocal? and self.groups?
       set(:groups, @resource[:groups])
     end
     if @resource.forcelocal? and @resource[:expiry]
       set(:expiry, @resource[:expiry])
     end
  end

  def groups?
    !!@resource[:groups]
  end
end
