module Puppet::Util::Windows::ADSI
  require 'ffi'

  class << self
    extend FFI::Library

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
      rescue WIN32OLERuntimeError => e
        raise Puppet::Error.new( "ADSI connection error: #{e}", e )
      end
    end

    def create(name, resource_type)
      Puppet::Util::Windows::ADSI.connect(computer_uri).Create(resource_type, name)
    end

    def delete(name, resource_type)
      Puppet::Util::Windows::ADSI.connect(computer_uri).Delete(resource_type, name)
    end

    # taken from winbase.h
    MAX_COMPUTERNAME_LENGTH = 31

    def computer_name
      unless @computer_name
        max_length = MAX_COMPUTERNAME_LENGTH + 1 # NULL terminated
        FFI::MemoryPointer.new(max_length * 2) do |buffer| # wide string
          FFI::MemoryPointer.new(:dword, 1) do |buffer_size|
            buffer_size.write_dword(max_length) # length in TCHARs

            if GetComputerNameW(buffer, buffer_size) == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new("Failed to get computer name")
            end
            @computer_name = buffer.read_wide_string(buffer_size.read_dword)
          end
        end
      end
      @computer_name
    end

    def computer_uri(host = '.')
      "WinNT://#{host}"
    end

    def wmi_resource_uri( host = '.' )
      "winmgmts:{impersonationLevel=impersonate}!//#{host}/root/cimv2"
    end

    # This method should *only* be used to generate WinNT://<SID> style monikers
    # used for IAdsGroup::Add / IAdsGroup::Remove.  These URIs are not useable
    # to resolve an account with WIN32OLE.connect
    # Valid input is a SID::Principal, S-X-X style SID string or any valid
    # account name with or without domain prefix
    # @api private
    def sid_uri_safe(sid)
      return sid_uri(sid) if sid.kind_of?(Puppet::Util::Windows::SID::Principal)

      begin
        sid = Puppet::Util::Windows::SID.name_to_sid_object(sid)
        sid_uri(sid)
      rescue Puppet::Util::Windows::Error, Puppet::Error
        nil
      end
    end

    # This method should *only* be used to generate WinNT://<SID> style monikers
    # used for IAdsGroup::Add / IAdsGroup::Remove.  These URIs are not useable
    # to resolve an account with WIN32OLE.connect
    def sid_uri(sid)
      raise Puppet::Error.new( "Must use a valid SID::Principal" ) if !sid.kind_of?(Puppet::Util::Windows::SID::Principal)

      "WinNT://#{sid.sid}"
    end

    def uri(resource_name, resource_type, host = '.')
      "#{computer_uri(host)}/#{resource_name},#{resource_type}"
    end

    def wmi_connection
      connect(wmi_resource_uri)
    end

    def execquery(query)
      wmi_connection.execquery(query)
    end

    ffi_convention :stdcall

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724295(v=vs.85).aspx
    # BOOL WINAPI GetComputerName(
    #   _Out_    LPTSTR lpBuffer,
    #   _Inout_  LPDWORD lpnSize
    # );
    ffi_lib :kernel32
    attach_function_private :GetComputerNameW,
      [:lpwstr, :lpdword], :win32_bool
  end

  module Shared
    def uri(name, host = '.')
      host = '.' if ['NT AUTHORITY', 'BUILTIN', Socket.gethostname].include?(host)

      # group or user
      account_type = self.name.split('::').last.downcase

      Puppet::Util::Windows::ADSI.uri(name, account_type, host)
    end

    def parse_name(name)
      if name =~ /\//
        raise Puppet::Error.new( "Value must be in DOMAIN\\user style syntax" )
      end

      matches = name.scan(/((.*)\\)?(.*)/)
      domain = matches[0][1] || '.'
      account = matches[0][2]

      return account, domain
    end

    def get_sids(adsi_child_collection)
      sids = []
      adsi_child_collection.each do |m|
        sids << Puppet::Util::Windows::SID.octet_string_to_sid_object(m.objectSID)
      end

      sids
    end

    def name_sid_hash(names)
      return {} if names.nil? || names.empty?

      sids = names.map do |name|
        sid = Puppet::Util::Windows::SID.name_to_sid_object(name)
        raise Puppet::Error.new( "Could not resolve name: #{name}" ) if !sid
        [sid.sid, sid]
      end

      Hash[ sids ]
    end
  end

  class User
    extend Enumerable
    extend Puppet::Util::Windows::ADSI::Shared
    extend FFI::Library

    # https://msdn.microsoft.com/en-us/library/aa746340.aspx
    # IADsUser interface

    require 'puppet/util/windows/sid'

    attr_accessor :native_user
    attr_reader :name, :sid
    def initialize(name, native_user = nil)
      @name = name
      @native_user = native_user
    end

    def native_user
      @native_user ||= Puppet::Util::Windows::ADSI.connect(self.class.uri(*self.class.parse_name(@name)))
    end

    def sid
      @sid ||= Puppet::Util::Windows::SID.octet_string_to_sid_object(native_user.objectSID)
    end

    def uri
      self.class.uri(sid.account, sid.domain)
    end

    def self.logon(name, password)
      Puppet::Util::Windows::User.password_is?(name, password)
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
      rescue WIN32OLERuntimeError => e
        # ERROR_BAD_USERNAME 2202L from winerror.h
        if e.message =~ /8007089A/m
          raise Puppet::Error.new(
           "Puppet is not able to create/delete domain users with the user resource.",
           e
          )
        end

        raise Puppet::Error.new( "User update failed: #{e}", e )
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
      if !password.nil?
        native_user.SetPassword(password)
        commit
      end

      fADS_UF_DONT_EXPIRE_PASSWD = 0x10000
      add_flag("UserFlags", fADS_UF_DONT_EXPIRE_PASSWD)
    end

    def groups
      # https://msdn.microsoft.com/en-us/library/aa746342.aspx
      # WIN32OLE objects aren't enumerable, so no map
      groups = []
      native_user.Groups.each {|g| groups << g.Name} rescue nil
      groups
    end

    def add_to_groups(*group_names)
      group_names.each do |group_name|
        Puppet::Util::Windows::ADSI::Group.new(group_name).add_member_sids(sid)
      end
    end
    alias add_to_group add_to_groups

    def remove_from_groups(*group_names)
      group_names.each do |group_name|
        Puppet::Util::Windows::ADSI::Group.new(group_name).remove_member_sids(sid)
      end
    end
    alias remove_from_group remove_from_groups


    def add_group_sids(*sids)
      group_names = sids.map { |s| s.domain_account }
      add_to_groups(*group_names)
    end

    def remove_group_sids(*sids)
      group_names = sids.map { |s| s.domain_account }
      remove_from_groups(*group_names)
    end

    def group_sids
      self.class.get_sids(native_user.Groups)
    end

    def set_groups(desired_groups, minimum = true)
      return if desired_groups.nil?

      desired_groups = desired_groups.split(',').map(&:strip)

      current_hash = Hash[ self.group_sids.map { |sid| [sid.sid, sid] } ]
      desired_hash = self.class.name_sid_hash(desired_groups)

      # First we add the user to all the groups it should be in but isn't
      if !desired_groups.empty?
        groups_to_add = (desired_hash.keys - current_hash.keys).map { |sid| desired_hash[sid] }
        add_group_sids(*groups_to_add)
      end

      # Then we remove the user from all groups it is in but shouldn't be, if
      # that's been requested
      if !minimum
        if desired_hash.empty?
          groups_to_remove = current_hash.values
        else
          groups_to_remove = (current_hash.keys - desired_hash.keys).map { |sid| current_hash[sid] }
        end

        remove_group_sids(*groups_to_remove)
      end
    end

    def self.create(name)
      # Windows error 1379: The specified local group already exists.
      raise Puppet::Error.new( "Cannot create user if group '#{name}' exists." ) if Puppet::Util::Windows::ADSI::Group.exists? name
      new(name, Puppet::Util::Windows::ADSI.create(name, 'user'))
    end

    # UNLEN from lmcons.h - https://stackoverflow.com/a/2155176
    MAX_USERNAME_LENGTH = 256
    def self.current_user_name
      user_name = ''
      max_length = MAX_USERNAME_LENGTH + 1 # NULL terminated
      FFI::MemoryPointer.new(max_length * 2) do |buffer| # wide string
        FFI::MemoryPointer.new(:dword, 1) do |buffer_size|
          buffer_size.write_dword(max_length) # length in TCHARs

          if GetUserNameW(buffer, buffer_size) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new("Failed to get user name")
          end
          # buffer_size includes trailing NULL
          user_name = buffer.read_wide_string(buffer_size.read_dword - 1)
        end
      end

      user_name
    end

    def self.exists?(name_or_sid)
      well_known = false
      if (sid = Puppet::Util::Windows::SID.name_to_sid_object(name_or_sid))
        return true if sid.account_type == :SidTypeUser

        # 'well known group' is special as it can be a group like Everyone OR a user like SYSTEM
        # so try to resolve it
        # https://msdn.microsoft.com/en-us/library/cc234477.aspx
        well_known = sid.account_type == :SidTypeWellKnownGroup
        return false if sid.account_type != :SidTypeAlias && !well_known
        name_or_sid = "#{sid.domain}\\#{sid.account}"
      end

      user = Puppet::Util::Windows::ADSI.connect(User.uri(*User.parse_name(name_or_sid)))
      # otherwise, verify that the account is actually a User account
      user.Class == 'User'
    rescue
      # special accounts like SYSTEM cannot resolve via moniker like WinNT://./SYSTEM,user
      # and thus fail to connect - so given a validly resolved SID, this failure is ambiguous as it
      # may indicate either a group like Service or an account like SYSTEM
      well_known
    end


    def self.delete(name)
      Puppet::Util::Windows::ADSI.delete(name, 'user')
    end

    def self.each(&block)
      wql = Puppet::Util::Windows::ADSI.execquery('select name from win32_useraccount where localaccount = "TRUE"')

      users = []
      wql.each do |u|
        users << new(u.name)
      end

      users.each(&block)
    end

    ffi_convention :stdcall

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724432(v=vs.85).aspx
    # BOOL WINAPI GetUserName(
    #   _Out_    LPTSTR lpBuffer,
    #   _Inout_  LPDWORD lpnSize
    # );
    ffi_lib :advapi32
    attach_function_private :GetUserNameW,
      [:lpwstr, :lpdword], :win32_bool
  end

  class UserProfile
    def self.delete(sid)
      begin
        Puppet::Util::Windows::ADSI.wmi_connection.Delete("Win32_UserProfile.SID='#{sid}'")
      rescue WIN32OLERuntimeError => e
        # https://social.technet.microsoft.com/Forums/en/ITCG/thread/0f190051-ac96-4bf1-a47f-6b864bfacee5
        # Prior to Vista SP1, there's no builtin way to programmatically
        # delete user profiles (except for delprof.exe). So try to delete
        # but warn if we fail
        raise e unless e.message.include?('80041010')

        Puppet.warning "Cannot delete user profile for '#{sid}' prior to Vista SP1"
      end
    end
  end

  class Group
    extend Enumerable
    extend Puppet::Util::Windows::ADSI::Shared

    # https://msdn.microsoft.com/en-us/library/aa706021.aspx
    # IADsGroup interface

    attr_accessor :native_group
    attr_reader :name, :sid
    def initialize(name, native_group = nil)
      @name = name
      @native_group = native_group
    end

    def uri
      self.class.uri(sid.account, sid.domain)
    end

    def native_group
      @native_group ||= Puppet::Util::Windows::ADSI.connect(self.class.uri(*self.class.parse_name(name)))
    end

    def sid
      @sid ||= Puppet::Util::Windows::SID.octet_string_to_sid_object(native_group.objectSID)
    end

    def commit
      begin
        native_group.SetInfo unless native_group.nil?
      rescue WIN32OLERuntimeError => e
        # ERROR_BAD_USERNAME 2202L from winerror.h
        if e.message =~ /8007089A/m
          raise Puppet::Error.new(
            "Puppet is not able to create/delete domain groups with the group resource.",
            e
          )
        end

        raise Puppet::Error.new( "Group update failed: #{e}", e )
      end
      self
    end

    def add_member_sids(*sids)
      sids.each do |sid|
        native_group.Add(Puppet::Util::Windows::ADSI.sid_uri(sid))
      end
    end

    def remove_member_sids(*sids)
      sids.each do |sid|
        native_group.Remove(Puppet::Util::Windows::ADSI.sid_uri(sid))
      end
    end

    def members
      # WIN32OLE objects aren't enumerable, so no map
      members = []
      native_group.Members.each {|m| members << m.Name}
      members
    end

    def member_sids
      self.class.get_sids(native_group.Members)
    end

    def set_members(desired_members, inclusive = true)
      return if desired_members.nil?

      current_hash = Hash[ self.member_sids.map { |sid| [sid.sid, sid] } ]
      desired_hash = self.class.name_sid_hash(desired_members)

      # First we add all missing members
      if !desired_hash.empty?
        members_to_add = (desired_hash.keys - current_hash.keys).map { |sid| desired_hash[sid] }
        add_member_sids(*members_to_add)
      end

      # Then we remove all extra members if inclusive
      if inclusive
        if desired_hash.empty?
          members_to_remove = current_hash.values
        else
          members_to_remove = (current_hash.keys - desired_hash.keys).map { |sid| current_hash[sid] }
        end

        remove_member_sids(*members_to_remove)
      end
    end

    def self.create(name)
      # Windows error 2224: The account already exists.
      raise Puppet::Error.new( "Cannot create group if user '#{name}' exists." ) if Puppet::Util::Windows::ADSI::User.exists? name
      new(name, Puppet::Util::Windows::ADSI.create(name, 'group'))
    end

    def self.exists?(name_or_sid)
      well_known = false
      if (sid = Puppet::Util::Windows::SID.name_to_sid_object(name_or_sid))
        return true if sid.account_type == :SidTypeGroup

        # 'well known group' is special as it can be a group like Everyone OR a user like SYSTEM
        # so try to resolve it
        # https://msdn.microsoft.com/en-us/library/cc234477.aspx
        well_known = sid.account_type == :SidTypeWellKnownGroup
        return false if sid.account_type != :SidTypeAlias && !well_known
        name_or_sid = "#{sid.domain}\\#{sid.account}"
      end

      user = Puppet::Util::Windows::ADSI.connect(Group.uri(*Group.parse_name(name_or_sid)))
      user.Class == 'Group'
    rescue
      # special groups like Authenticated Users cannot resolve via moniker like WinNT://./Authenticated Users,group
      # and thus fail to connect - so given a validly resolved SID, this failure is ambiguous as it
      # may indicate either a group like Service or an account like SYSTEM
      well_known
    end

    def self.delete(name)
      Puppet::Util::Windows::ADSI.delete(name, 'group')
    end

    def self.each(&block)
      wql = Puppet::Util::Windows::ADSI.execquery( 'select name from win32_group where localaccount = "TRUE"' )

      groups = []
      wql.each do |g|
        groups << new(g.name)
      end

      groups.each(&block)
    end
  end
end
