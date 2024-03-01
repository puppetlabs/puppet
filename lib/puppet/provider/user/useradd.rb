# frozen_string_literal: true

require_relative '../../../puppet/provider/nameservice/objectadd'
require 'date'
require_relative '../../../puppet/util/libuser'
require 'time'
require_relative '../../../puppet/error'

Puppet::Type.type(:user).provide :useradd, :parent => Puppet::Provider::NameService::ObjectAdd do
  desc "User management via `useradd` and its ilk.  Note that you will need to
    install Ruby's shadow password library (often known as `ruby-libshadow`)
    if you wish to manage user passwords.

    To use the `forcelocal` parameter, you need to install the `libuser` package (providing
    `/usr/sbin/lgroupadd` and `/usr/sbin/luseradd`)."

  commands :add => "useradd", :delete => "userdel", :modify => "usermod", :password => "chage", :chpasswd => "chpasswd"

  options :home, :flag => "-d", :method => :dir
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :password_min_age, :flag => "-m", :method => :sp_min
  options :password_max_age, :flag => "-M", :method => :sp_max
  options :password_warn_days, :flag => "-W", :method => :sp_warn
  options :password, :method => :sp_pwdp
  options :expiry, :method => :sp_expire,
                   :munge => proc { |value|
                               if value == :absent
                                 if Puppet.runtime[:facter].value('os.name') == 'SLES' && Puppet.runtime[:facter].value('os.release.major') == "11"
                                   -1
                                 else
                                   ''
                                 end
                               else
                                 case Puppet.runtime[:facter].value('os.name')
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
                                   (Date.new(1970, 1, 1) + value).strftime('%Y-%m-%d')
                                 end
                               }

  optional_commands :localadd => "luseradd", :localdelete => "luserdel", :localmodify => "lusermod", :localpassword => "lchage"
  has_feature :manages_local_users_and_groups if Puppet.features.libuser?

  def exists?
    return !!localuid if @resource.forcelocal?

    super
  end

  def uid
    return localuid if @resource.forcelocal?

    get(:uid)
  end

  def gid
    return localgid if @resource.forcelocal?

    get(:gid)
  end

  def comment
    return localcomment if @resource.forcelocal?

    get(:comment)
  end

  def shell
    return localshell if @resource.forcelocal?

    get(:shell)
  end

  def home
    return localhome if @resource.forcelocal?

    get(:home)
  end

  def groups
    return localgroups if @resource.forcelocal?

    super
  end

  def finduser(key, value)
    passwd_file = '/etc/passwd'
    passwd_keys = [:account, :password, :uid, :gid, :gecos, :directory, :shell]

    unless @users
      unless Puppet::FileSystem.exist?(passwd_file)
        raise Puppet::Error, "Forcelocal set for user resource '#{resource[:name]}', but #{passwd_file} does not exist"
      end

      @users = []
      Puppet::FileSystem.each_line(passwd_file) do |line|
        user = line.chomp.split(':')
        @users << passwd_keys.zip(user).to_h
      end
    end
    @users.find { |param| param[key] == value } || false
  end

  def local_username
    finduser(:uid, @resource.uid)
  end

  def localuid
    user = finduser(:account, resource[:name])
    return user[:uid] if user

    false
  end

  def localgid
    user = finduser(:account, resource[:name])
    if user
      begin
        return Integer(user[:gid])
      rescue ArgumentError
        Puppet.debug("Non-numeric GID found in /etc/passwd for user #{resource[:name]}")
        return user[:gid]
      end
    end
    false
  end

  def localcomment
    user = finduser(:account, resource[:name])
    user[:gecos]
  end

  def localshell
    user = finduser(:account, resource[:name])
    user[:shell]
  end

  def localhome
    user = finduser(:account, resource[:name])
    user[:directory]
  end

  def localgroups
    @groups_of ||= {}
    group_file = '/etc/group'
    user = resource[:name]

    return @groups_of[user] if @groups_of[user]

    @groups_of[user] = []

    unless Puppet::FileSystem.exist?(group_file)
      raise Puppet::Error, "Forcelocal set for user resource '#{user}', but #{group_file} does not exist"
    end

    Puppet::FileSystem.each_line(group_file) do |line|
      data = line.chomp.split(':')
      if !data.empty? && data.last.split(',').include?(user)
        @groups_of[user] << data.first
      end
    end

    @groups_of[user]
  end

  def shell=(value)
    check_valid_shell
    set(:shell, value)
  end

  def groups=(value)
    set(:groups, value)
  end

  def password=(value)
    user = @resource[:name]
    tempfile = Tempfile.new('puppet', :encoding => Encoding::UTF_8)
    begin
      # Puppet execute does not support strings as input, only files.
      # The password is expected to be in an encrypted format given -e is specified:
      tempfile << "#{user}:#{value}\n"
      tempfile.flush

      # Options '-e' use encrypted password
      # Must receive "user:enc_password" as input
      # command, arguments = {:failonfail => true, :combine => true}
      cmd = [command(:chpasswd), '-e']
      execute_options = {
        :failonfail => false,
        :combine => true,
        :stdinfile => tempfile.path,
        :sensitive => has_sensitive_data?
      }
      output = execute(cmd, execute_options)
    rescue => detail
      tempfile.close
      tempfile.delete
      raise Puppet::Error, "Could not set password on #{@resource.class.name}[#{@resource.name}]: #{detail}", detail.backtrace
    end

    # chpasswd can return 1, even on success (at least on AIX 6.1); empty output
    # indicates success
    raise Puppet::ExecutionFailure, "chpasswd said #{output}" if output != ''
  end

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :groups, "Groups must be comma-separated" do |value|
    value !~ /\s/
  end

  has_features :manages_homedir, :allows_duplicates, :manages_expiry
  has_features :system_users unless %w[HP-UX Solaris].include? Puppet.runtime[:facter].value('os.name')

  has_features :manages_passwords, :manages_password_age if Puppet.features.libshadow?
  has_features :manages_shell

  def check_allow_dup
    # We have to manually check for duplicates when using libuser
    # because by default duplicates are allowed.  This check is
    # to ensure consistent behaviour of the useradd provider when
    # using both useradd and luseradd
    if (!@resource.allowdupe?) && @resource.forcelocal?
      if @resource.should(:uid) && finduser(:uid, @resource.should(:uid).to_s)
        raise(Puppet::Error, "UID #{@resource.should(:uid)} already exists, use allowdupe to force user creation")
      end
    elsif @resource.allowdupe? && (!@resource.forcelocal?)
      return ["-o"]
    end
    []
  end

  def check_valid_shell
    unless File.exist?(@resource.should(:shell))
      raise(Puppet::Error, "Shell #{@resource.should(:shell)} must exist")
    end
    unless File.executable?(@resource.should(:shell).to_s)
      raise(Puppet::Error, "Shell #{@resource.should(:shell)} must be executable")
    end
  end

  def check_manage_home
    cmd = []
    if @resource.managehome?
      # libuser does not implement the -m flag
      cmd << "-m" unless @resource.forcelocal?
    else
      osfamily = Puppet.runtime[:facter].value('os.family')
      osversion = Puppet.runtime[:facter].value('os.release.major').to_i
      # SLES 11 uses pwdutils instead of shadow, which does not have -M
      # Solaris and OpenBSD use different useradd flavors
      unless osfamily =~ /Solaris|OpenBSD/ || osfamily == 'Suse' && osversion <= 11
        cmd << "-M"
      end
    end
    cmd
  end

  def check_system_users
    if self.class.system_users? && resource.system?
      ["-r"]
    else
      []
    end
  end

  # Add properties and flags but skipping password related properties due to
  # security risks
  def add_properties
    cmd = []
    # validproperties is a list of properties in undefined order
    # sort them to have a predictable command line in tests
    Puppet::Type.type(:user).validproperties.sort.each do |property|
      value = get_value_for_property(property)
      next if value.nil? || property == :password

      # the value needs to be quoted, mostly because -c might
      # have spaces in it
      cmd << flag(property) << munge(property, value)
    end
    cmd
  end

  def get_value_for_property(property)
    return nil if property == :ensure
    return nil if property_manages_password_age?(property)
    return nil if property == :groups and @resource.forcelocal?
    return nil if property == :expiry and @resource.forcelocal?

    value = @resource.should(property)
    return nil if !value || value == ""

    value
  end

  def has_sensitive_data?(property = nil)
    # Check for sensitive values?
    properties = property ? [property] : Puppet::Type.type(:user).validproperties
    properties.any? do |prop|
      p = @resource.parameter(prop)
      p && p.respond_to?(:is_sensitive) && p.is_sensitive
    end
  end

  def addcmd
    if @resource.forcelocal?
      cmd = [command(:localadd)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:add)]
    end
    if (!@resource.should(:gid)) && Puppet::Util.gid(@resource[:name])
      cmd += ["-g", @resource[:name]]
    end
    cmd += add_properties
    cmd += check_allow_dup
    cmd += check_manage_home
    cmd += check_system_users
    cmd << @resource[:name]
  end

  def modifycmd(param, value)
    if @resource.forcelocal?
      case param
      when :groups, :expiry
        cmd = [command(:modify)]
      else
        cmd = [command(property_manages_password_age?(param) ? :localpassword : :localmodify)]
      end
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(property_manages_password_age?(param) ? :password : :modify)]
    end
    cmd << flag(param) << value
    cmd += check_allow_dup if param == :uid
    cmd << @resource[:name]

    cmd
  end

  def deletecmd
    if @resource.forcelocal?
      cmd = [command(:localdelete)]
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = [command(:delete)]
    end
    # Solaris `userdel -r` will fail if the homedir does not exist.
    if @resource.managehome? && (('Solaris' != Puppet.runtime[:facter].value('os.name')) || Dir.exist?(Dir.home(@resource[:name])))
      cmd << '-r'
    end
    cmd << @resource[:name]
  end

  def passcmd
    if @resource.forcelocal?
      cmd = command(:localpassword)
      @custom_environment = Puppet::Util::Libuser.getenv
    else
      cmd = command(:password)
    end
    age_limits = [:password_min_age, :password_max_age, :password_warn_days].select { |property| @resource.should(property) }
    if age_limits.empty?
      nil
    else
      [cmd, age_limits.collect { |property| [flag(property), @resource.should(property)] }, @resource[:name]].flatten
    end
  end

  [:expiry, :password_min_age, :password_max_age, :password_warn_days, :password].each do |shadow_property|
    define_method(shadow_property) do
      if Puppet.features.libshadow?
        ent = Shadow::Passwd.getspnam(@canonical_name)
        if ent
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
    if @resource.forcelocal?
      set(:groups, @resource[:groups]) if self.groups?
      set(:expiry, @resource[:expiry]) if @resource[:expiry]
    end
    set(:password, @resource[:password]) if @resource[:password]
  end

  def groups?
    !!@resource[:groups]
  end

  def property_manages_password_age?(property)
    property.to_s =~ /password_.+_age|password_warn_days/
  end
end
