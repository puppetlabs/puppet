module Puppet::Util::ADSI
  class << self
    def connectable?(uri)
      begin
        !! connect(uri)
      rescue
        false
      end
    end

    def connect(uri)
      begin
        WIN32OLE.connect(uri)
      rescue Exception => e
        raise Puppet::Error.new( "ADSI connection error: #{e}" )
      end
    end

    def create(name, resource_type)
      Puppet::Util::ADSI.connect(computer_uri).Create(resource_type, name)
    end

    def delete(name, resource_type)
      Puppet::Util::ADSI.connect(computer_uri).Delete(resource_type, name)
    end

    def computer_name
      unless @computer_name
        buf = " " * 128
        Win32API.new('kernel32', 'GetComputerName', ['P','P'], 'I').call(buf, buf.length.to_s)
        @computer_name = buf.unpack("A*")
      end
      @computer_name
    end

    def computer_uri
      "WinNT://#{computer_name}"
    end

    def wmi_resource_uri( host = '.' )
      "winmgmts:{impersonationLevel=impersonate}!//#{host}/root/cimv2"
    end

    def uri(resource_name, resource_type)
      "#{computer_uri}/#{resource_name},#{resource_type}"
    end

    def execquery(query)
      connect(wmi_resource_uri).execquery(query)
    end

    def sid_for_account(name)
      sid = nil
      if name =~ /\\/
        domain, name = name.split('\\', 2)
        query = "SELECT Sid from Win32_Account WHERE Name = '#{name}' AND Domain = '#{domain}' AND LocalAccount = true"
      else
        query = "SELECT Sid from Win32_Account WHERE Name = '#{name}' AND LocalAccount = true"
      end
      execquery(query).each { |u| sid ||= u.Sid }
      sid
    end
  end

  class User
    extend Enumerable

    attr_accessor :native_user
    attr_reader :name
    def initialize(name, native_user = nil)
      @name = name
      @native_user = native_user
    end

    def native_user
      @native_user ||= Puppet::Util::ADSI.connect(uri)
    end

    def self.uri(name)
      Puppet::Util::ADSI.uri(name, 'user')
    end

    def uri
      self.class.uri(name)
    end

    def self.logon(name, password)
      fLOGON32_LOGON_NETWORK = 3
      fLOGON32_PROVIDER_DEFAULT = 0

      logon_user = Win32API.new("advapi32", "LogonUser", ['P', 'P', 'P', 'L', 'L', 'P'], 'L')
      close_handle = Win32API.new("kernel32", "CloseHandle", ['P'], 'V')

      token = ' ' * 4
      if logon_user.call(name, "", password, fLOGON32_LOGON_NETWORK, fLOGON32_PROVIDER_DEFAULT, token) != 0
        close_handle.call(token.unpack('L')[0])
        true
      else
        false
      end
    end

    def [](attribute)
      native_user.Get(attribute)
    end

    def []=(attribute, value)
      native_user.Put(attribute, value)
    end

    def commit
      begin
        native_user.SetInfo unless native_user.nil?
      rescue Exception => e
        raise Puppet::Error.new( "User update failed: #{e}" )
      end
      self
    end

    def password_is?(password)
      self.class.logon(name, password)
    end

    def add_flag(flag_name, value)
      flag = native_user.Get(flag_name) rescue 0

      native_user.Put(flag_name, flag | value)

      commit
    end

    def password=(password)
      native_user.SetPassword(password)
      commit
      fADS_UF_DONT_EXPIRE_PASSWD = 0x10000
      add_flag("UserFlags", fADS_UF_DONT_EXPIRE_PASSWD)
    end

    def groups
      # WIN32OLE objects aren't enumerable, so no map
      groups = []
      native_user.Groups.each {|g| groups << g.Name} rescue nil
      groups
    end

    def add_to_groups(*group_names)
      group_names.each do |group_name|
        Puppet::Util::ADSI::Group.new(group_name).add_member(@name)
      end
    end
    alias add_to_group add_to_groups

    def remove_from_groups(*group_names)
      group_names.each do |group_name|
        Puppet::Util::ADSI::Group.new(group_name).remove_member(@name)
      end
    end
    alias remove_from_group remove_from_groups

    def set_groups(desired_groups, minimum = true)
      return if desired_groups.nil? or desired_groups.empty?

      desired_groups = desired_groups.split(',').map(&:strip)

      current_groups = self.groups

      # First we add the user to all the groups it should be in but isn't
      groups_to_add = desired_groups - current_groups
      add_to_groups(*groups_to_add)

      # Then we remove the user from all groups it is in but shouldn't be, if
      # that's been requested
      groups_to_remove = current_groups - desired_groups
      remove_from_groups(*groups_to_remove) unless minimum
    end

    def self.create(name)
      # Windows error 1379: The specified local group already exists.
      raise Puppet::Error.new( "Cannot create user if group '#{name}' exists." ) if Puppet::Util::ADSI::Group.exists? name
      new(name, Puppet::Util::ADSI.create(name, 'user'))
    end

    def self.exists?(name)
      Puppet::Util::ADSI::connectable?(User.uri(name))
    end

    def self.delete(name)
      Puppet::Util::ADSI.delete(name, 'user')
    end

    def self.each(&block)
      wql = Puppet::Util::ADSI.execquery("select * from win32_useraccount")

      users = []
      wql.each do |u|
        users << new(u.name, u)
      end

      users.each(&block)
    end
  end

  class Group
    extend Enumerable

    attr_accessor :native_group
    attr_reader :name
    def initialize(name, native_group = nil)
      @name = name
      @native_group = native_group
    end

    def uri
      self.class.uri(name)
    end

    def self.uri(name)
      Puppet::Util::ADSI.uri(name, 'group')
    end

    def native_group
      @native_group ||= Puppet::Util::ADSI.connect(uri)
    end

    def commit
      begin
        native_group.SetInfo unless native_group.nil?
      rescue Exception => e
        raise Puppet::Error.new( "Group update failed: #{e}" )
      end
      self
    end

    def add_members(*names)
      names.each do |name|
        native_group.Add(Puppet::Util::ADSI::User.uri(name))
      end
    end
    alias add_member add_members

    def remove_members(*names)
      names.each do |name|
        native_group.Remove(Puppet::Util::ADSI::User.uri(name))
      end
    end
    alias remove_member remove_members

    def members
      # WIN32OLE objects aren't enumerable, so no map
      members = []
      native_group.Members.each {|m| members << m.Name}
      members
    end

    def set_members(desired_members)
      return if desired_members.nil? or desired_members.empty?

      current_members = self.members

      # First we add all missing members
      members_to_add = desired_members - current_members
      add_members(*members_to_add)

      # Then we remove all extra members
      members_to_remove = current_members - desired_members
      remove_members(*members_to_remove)
    end

    def self.create(name)
      # Windows error 2224: The account already exists.
      raise Puppet::Error.new( "Cannot create group if user '#{name}' exists." ) if Puppet::Util::ADSI::User.exists? name
      new(name, Puppet::Util::ADSI.create(name, 'group'))
    end

    def self.exists?(name)
      Puppet::Util::ADSI.connectable?(Group.uri(name))
    end

    def self.delete(name)
      Puppet::Util::ADSI.delete(name, 'group')
    end

    def self.each(&block)
      wql = Puppet::Util::ADSI.execquery( "select * from win32_group" )

      groups = []
      wql.each do |g|
        groups << new(g.name, g)
      end

      groups.each(&block)
    end
  end
end
