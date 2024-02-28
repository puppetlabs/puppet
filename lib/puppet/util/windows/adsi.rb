# frozen_string_literal: true

module Puppet::Util::Windows::ADSI
  require 'ffi'

  # https://docs.microsoft.com/en-us/windows/win32/api/dsrole/ne-dsrole-dsrole_machine_role
  STANDALONE_WORKSTATION = 0
  MEMBER_WORKSTATION = 1
  STANDALONE_SERVER = 2
  MEMBER_SERVER = 3
  BACKUP_DOMAIN_CONTROLLER = 4
  PRIMARY_DOMAIN_CONTROLLER = 5

  DOMAIN_ROLES = {
    STANDALONE_WORKSTATION => :STANDALONE_WORKSTATION,
    MEMBER_WORKSTATION => :MEMBER_WORKSTATION,
    STANDALONE_SERVER => :STANDALONE_SERVER,
    MEMBER_SERVER => :MEMBER_SERVER,
    BACKUP_DOMAIN_CONTROLLER => :BACKUP_DOMAIN_CONTROLLER,
    PRIMARY_DOMAIN_CONTROLLER => :PRIMARY_DOMAIN_CONTROLLER,
  }

  class << self
    extend FFI::Library

    def connectable?(uri)
      begin
        !!connect(uri)
      rescue
        false
      end
    end

    def connect(uri)
      begin
        WIN32OLE.connect(uri)
      rescue WIN32OLERuntimeError => e
        raise Puppet::Error.new(_("ADSI connection error: %{e}") % { e: e }, e)
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
              raise Puppet::Util::Windows::Error.new(_("Failed to get computer name"))
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

    def wmi_resource_uri(host = '.')
      "winmgmts:{impersonationLevel=impersonate}!//#{host}/root/cimv2"
    end

    # This method should *only* be used to generate WinNT://<SID> style monikers
    # used for IAdsGroup::Add / IAdsGroup::Remove.  These URIs are not usable
    # to resolve an account with WIN32OLE.connect
    # Valid input is a SID::Principal, S-X-X style SID string or any valid
    # account name with or without domain prefix
    # @api private
    def sid_uri_safe(sid)
      return sid_uri(sid) if sid.is_a?(Puppet::Util::Windows::SID::Principal)

      begin
        sid = Puppet::Util::Windows::SID.name_to_principal(sid)
        sid_uri(sid)
      rescue Puppet::Util::Windows::Error, Puppet::Error
        nil
      end
    end

    # This method should *only* be used to generate WinNT://<SID> style monikers
    # used for IAdsGroup::Add / IAdsGroup::Remove.  These URIs are not useable
    # to resolve an account with WIN32OLE.connect
    def sid_uri(sid)
      raise Puppet::Error.new(_("Must use a valid SID::Principal")) unless sid.is_a?(Puppet::Util::Windows::SID::Principal)

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

    def domain_role
      unless @domain_role
        query_result = Puppet::Util::Windows::ADSI.execquery('select DomainRole from Win32_ComputerSystem').to_enum.first
        @domain_role = DOMAIN_ROLES[query_result.DomainRole] if query_result
      end
      @domain_role
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

  # Common base class shared by the User and Group
  # classes below.
  class ADSIObject
    extend Enumerable

    # Define some useful class-level methods
    class << self
      # Is either 'user' or 'group'
      attr_reader :object_class

      def localized_domains
        @localized_domains ||= [
          # localized version of BUILTIN
          # for instance VORDEFINIERT on German Windows
          Puppet::Util::Windows::SID.sid_to_name('S-1-5-32').upcase,
          # localized version of NT AUTHORITY (can't use S-1-5)
          # for instance AUTORITE NT on French Windows
          Puppet::Util::Windows::SID.name_to_principal('SYSTEM').domain.upcase
        ]
      end

      def uri(name, host = '.')
        host = '.' if (localized_domains << Socket.gethostname.upcase).include?(host.upcase)
        Puppet::Util::Windows::ADSI.uri(name, @object_class, host)
      end

      def parse_name(name)
        if name =~ /\//
          raise Puppet::Error.new(_("Value must be in DOMAIN\\%{object_class} style syntax") % { object_class: @object_class })
        end

        matches = name.scan(/((.*)\\)?(.*)/)
        domain = matches[0][1] || '.'
        account = matches[0][2]

        return account, domain
      end

      # returns Puppet::Util::Windows::SID::Principal[]
      # may contain objects that represent unresolvable SIDs
      def get_sids(adsi_child_collection)
        sids = []
        adsi_child_collection.each do |m|
          sids << Puppet::Util::Windows::SID.ads_to_principal(m)
        rescue Puppet::Util::Windows::Error => e
          case e.code
          when Puppet::Util::Windows::SID::ERROR_TRUSTED_RELATIONSHIP_FAILURE, Puppet::Util::Windows::SID::ERROR_TRUSTED_DOMAIN_FAILURE
            sids << Puppet::Util::Windows::SID.unresolved_principal(m.name, m.sid)
          else
            raise e
          end
        end

        sids
      end

      def name_sid_hash(names, allow_unresolved = false)
        return {} if names.nil? || names.empty?

        sids = names.map do |name|
          sid = Puppet::Util::Windows::SID.name_to_principal(name, allow_unresolved)
          raise Puppet::Error.new(_("Could not resolve name: %{name}") % { name: name }) unless sid

          [sid.sid, sid]
        end

        sids.to_h
      end

      def delete(name)
        Puppet::Util::Windows::ADSI.delete(name, @object_class)
      end

      def exists?(name_or_sid)
        well_known = false
        if (sid = Puppet::Util::Windows::SID.name_to_principal(name_or_sid))
          # Examples of SidType include SidTypeUser, SidTypeGroup
          if sid.account_type == "SidType#{@object_class.capitalize}".to_sym
            # Check if we're getting back a local user when domain-joined
            return true unless [:MEMBER_WORKSTATION, :MEMBER_SERVER].include?(Puppet::Util::Windows::ADSI.domain_role)

            # The resource domain and the computer name are not always case-matching
            return sid.domain.casecmp(Puppet::Util::Windows::ADSI.computer_name) == 0
          end

          # 'well known group' is special as it can be a group like Everyone OR a user like SYSTEM
          # so try to resolve it
          # https://msdn.microsoft.com/en-us/library/cc234477.aspx
          well_known = sid.account_type == :SidTypeWellKnownGroup
          return false if sid.account_type != :SidTypeAlias && !well_known

          name_or_sid = "#{sid.domain}\\#{sid.account}"
        end

        object = Puppet::Util::Windows::ADSI.connect(uri(*parse_name(name_or_sid)))
        object.Class.downcase == @object_class
      rescue
        # special accounts like SYSTEM or special groups like Authenticated Users cannot
        # resolve via monikers like WinNT://./SYSTEM,user or WinNT://./Authenticated Users,group
        # -- they'll fail to connect. thus, given a validly resolved SID, this failure is
        # ambiguous as it may indicate either a group like Service or an account like SYSTEM
        well_known
      end

      def list_all
        raise NotImplementedError, _("Subclass must implement class-level method 'list_all'!")
      end

      def each(&block)
        objects = []
        list_all.each do |o|
          # Setting WIN32OLE.codepage in the microsoft_windows feature ensures
          # values are returned as UTF-8
          objects << new(o.name)
        end

        objects.each(&block)
      end
    end

    attr_reader :name

    def initialize(name, native_object = nil)
      @name = name
      @native_object = native_object
    end

    def object_class
      self.class.object_class
    end

    def uri
      self.class.uri(sid.account, sid.domain)
    end

    def native_object
      @native_object ||= Puppet::Util::Windows::ADSI.connect(self.class.uri(*self.class.parse_name(name)))
    end

    def sid
      @sid ||= Puppet::Util::Windows::SID.octet_string_to_principal(native_object.objectSID)
    end

    def [](attribute)
      # Setting WIN32OLE.codepage ensures values are returned as UTF-8
      native_object.Get(attribute)
    end

    def []=(attribute, value)
      native_object.Put(attribute, value)
    end

    def commit
      begin
        native_object.SetInfo
      rescue WIN32OLERuntimeError => e
        # ERROR_BAD_USERNAME 2202L from winerror.h
        if e.message =~ /8007089A/m
          raise Puppet::Error.new(
            _("Puppet is not able to create/delete domain %{object_class} objects with the %{object_class} resource.") % { object_class: object_class },
          )
        end

        raise Puppet::Error.new(_("%{object_class} update failed: %{error}") % { object_class: object_class.capitalize, error: e }, e)
      end
      self
    end
  end

  class User < ADSIObject
    extend FFI::Library

    require_relative '../../../puppet/util/windows/sid'

    # https://msdn.microsoft.com/en-us/library/aa746340.aspx
    # IADsUser interface
    @object_class = 'user'

    class << self
      def list_all
        Puppet::Util::Windows::ADSI.execquery('select name from win32_useraccount where localaccount = "TRUE"')
      end

      def logon(name, password)
        Puppet::Util::Windows::User.password_is?(name, password)
      end

      def create(name)
        # Windows error 1379: The specified local group already exists.
        raise Puppet::Error.new(_("Cannot create user if group '%{name}' exists.") % { name: name }) if Puppet::Util::Windows::ADSI::Group.exists? name

        new(name, Puppet::Util::Windows::ADSI.create(name, @object_class))
      end
    end

    def password_is?(password)
      self.class.logon(name, password)
    end

    def add_flag(flag_name, value)
      flag = native_object.Get(flag_name) rescue 0

      native_object.Put(flag_name, flag | value)

      commit
    end

    def password=(password)
      unless password.nil?
        native_object.SetPassword(password)
        commit
      end

      fADS_UF_DONT_EXPIRE_PASSWD = 0x10000
      add_flag("UserFlags", fADS_UF_DONT_EXPIRE_PASSWD)
    end

    def groups
      # https://msdn.microsoft.com/en-us/library/aa746342.aspx
      # WIN32OLE objects aren't enumerable, so no map
      groups = []
      # Setting WIN32OLE.codepage ensures values are returned as UTF-8
      native_object.Groups.each { |g| groups << g.Name } rescue nil
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
      self.class.get_sids(native_object.Groups)
    end

    # TODO: This code's pretty similar to set_members in the Group class. Would be nice
    # to refactor them into the ADSIObject class at some point. This was not done originally
    # because these use different methods to do stuff that are also aliased to other methods,
    # so the shared code isn't exactly a 1:1 mapping.
    def set_groups(desired_groups, minimum = true)
      return if desired_groups.nil?

      desired_groups = desired_groups.split(',').map(&:strip)

      current_hash = self.group_sids.to_h { |sid| [sid.sid, sid] }
      desired_hash = self.class.name_sid_hash(desired_groups)

      # First we add the user to all the groups it should be in but isn't
      unless desired_groups.empty?
        groups_to_add = (desired_hash.keys - current_hash.keys).map { |sid| desired_hash[sid] }
        add_group_sids(*groups_to_add)
      end

      # Then we remove the user from all groups it is in but shouldn't be, if
      # that's been requested
      unless minimum
        if desired_hash.empty?
          groups_to_remove = current_hash.values
        else
          groups_to_remove = (current_hash.keys - desired_hash.keys).map { |sid| current_hash[sid] }
        end

        remove_group_sids(*groups_to_remove)
      end
    end

    # Declare all of the available user flags on the system. Note that
    # ADS_UF is read as ADS_UserFlag
    #   https://docs.microsoft.com/en-us/windows/desktop/api/iads/ne-iads-ads_user_flag
    # and
    #   https://support.microsoft.com/en-us/help/305144/how-to-use-the-useraccountcontrol-flags-to-manipulate-user-account-pro
    # for the flag values.
    ADS_USERFLAGS = {
      ADS_UF_SCRIPT: 0x0001,
      ADS_UF_ACCOUNTDISABLE: 0x0002,
      ADS_UF_HOMEDIR_REQUIRED: 0x0008,
      ADS_UF_LOCKOUT: 0x0010,
      ADS_UF_PASSWD_NOTREQD: 0x0020,
      ADS_UF_PASSWD_CANT_CHANGE: 0x0040,
      ADS_UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED: 0x0080,
      ADS_UF_TEMP_DUPLICATE_ACCOUNT: 0x0100,
      ADS_UF_NORMAL_ACCOUNT: 0x0200,
      ADS_UF_INTERDOMAIN_TRUST_ACCOUNT: 0x0800,
      ADS_UF_WORKSTATION_TRUST_ACCOUNT: 0x1000,
      ADS_UF_SERVER_TRUST_ACCOUNT: 0x2000,
      ADS_UF_DONT_EXPIRE_PASSWD: 0x10000,
      ADS_UF_MNS_LOGON_ACCOUNT: 0x20000,
      ADS_UF_SMARTCARD_REQUIRED: 0x40000,
      ADS_UF_TRUSTED_FOR_DELEGATION: 0x80000,
      ADS_UF_NOT_DELEGATED: 0x100000,
      ADS_UF_USE_DES_KEY_ONLY: 0x200000,
      ADS_UF_DONT_REQUIRE_PREAUTH: 0x400000,
      ADS_UF_PASSWORD_EXPIRED: 0x800000,
      ADS_UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION: 0x1000000
    }

    def userflag_set?(flag)
      flag_value = ADS_USERFLAGS[flag] || 0
      !(self['UserFlags'] & flag_value).zero?
    end

    # Common helper for set_userflags and unset_userflags.
    #
    # @api private
    def op_userflags(*flags, &block)
      # Avoid an unnecessary set + commit operation.
      return if flags.empty?

      unrecognized_flags = flags.reject { |flag| ADS_USERFLAGS.keys.include?(flag) }
      unless unrecognized_flags.empty?
        raise ArgumentError, _("Unrecognized ADS UserFlags: %{unrecognized_flags}") % { unrecognized_flags: unrecognized_flags.join(', ') }
      end

      self['UserFlags'] = flags.inject(self['UserFlags'], &block)
    end

    def set_userflags(*flags)
      op_userflags(*flags) { |userflags, flag| userflags | ADS_USERFLAGS[flag] }
    end

    def unset_userflags(*flags)
      op_userflags(*flags) { |userflags, flag| userflags & ~ADS_USERFLAGS[flag] }
    end

    def disabled?
      userflag_set?(:ADS_UF_ACCOUNTDISABLE)
    end

    def locked_out?
      # Note that the LOCKOUT flag is known to be inaccurate when using the
      # LDAP IADsUser provider, but this class consistently uses the WinNT
      # provider, which is expected to be accurate.
      userflag_set?(:ADS_UF_LOCKOUT)
    end

    def expired?
      expires = native_object.Get('AccountExpirationDate')
      expires && expires < Time.now
    rescue WIN32OLERuntimeError => e
      # This OLE error code indicates the property can't be found in the cache
      raise e unless e.message =~ /8000500D/m

      false
    end

    # UNLEN from lmcons.h - https://stackoverflow.com/a/2155176
    MAX_USERNAME_LENGTH = 256
    def self.current_user_name
      user_name = ''.dup
      max_length = MAX_USERNAME_LENGTH + 1 # NULL terminated
      FFI::MemoryPointer.new(max_length * 2) do |buffer| # wide string
        FFI::MemoryPointer.new(:dword, 1) do |buffer_size|
          buffer_size.write_dword(max_length) # length in TCHARs

          if GetUserNameW(buffer, buffer_size) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new(_("Failed to get user name"))
          end

          # buffer_size includes trailing NULL
          user_name = buffer.read_wide_string(buffer_size.read_dword - 1)
        end
      end

      user_name
    end

    # https://docs.microsoft.com/en-us/windows/win32/api/secext/ne-secext-extended_name_format
    NameUnknown           = 0
    NameFullyQualifiedDN  = 1
    NameSamCompatible     = 2
    NameDisplay           = 3
    NameUniqueId          = 6
    NameCanonical         = 7
    NameUserPrincipal     = 8
    NameCanonicalEx       = 9
    NameServicePrincipal  = 10
    NameDnsDomain         = 12
    NameGivenName         = 13
    NameSurname           = 14

    def self.current_user_name_with_format(format)
      user_name = ''.dup
      max_length = 1024

      FFI::MemoryPointer.new(:lpwstr, max_length * 2 + 1) do |buffer|
        FFI::MemoryPointer.new(:dword, 1) do |buffer_size|
          buffer_size.write_dword(max_length + 1)

          if GetUserNameExW(format.to_i, buffer, buffer_size) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new(_("Failed to get user name"), FFI.errno)
          end

          user_name = buffer.read_wide_string(buffer_size.read_dword).chomp
        end
      end

      user_name
    end

    def self.current_sam_compatible_user_name
      current_user_name_with_format(NameSamCompatible)
    end

    def self.current_user_sid
      Puppet::Util::Windows::SID.name_to_principal(current_user_name)
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

    # https://docs.microsoft.com/en-us/windows/win32/api/secext/nf-secext-getusernameexa
    # BOOLEAN SEC_ENTRY GetUserNameExA(
    #   EXTENDED_NAME_FORMAT NameFormat,
    #   LPSTR                lpNameBuffer,
    #   PULONG               nSize
    # );type
    ffi_lib :secur32
    attach_function_private :GetUserNameExW, [:uint16, :lpwstr, :pointer], :win32_bool
  end

  class UserProfile
    def self.delete(sid)
      begin
        Puppet::Util::Windows::ADSI.wmi_connection.Delete("Win32_UserProfile.SID='#{sid}'")
      rescue WIN32OLERuntimeError => e
        # https://social.technet.microsoft.com/Forums/en/ITCG/thread/0f190051-ac96-4bf1-a47f-6b864bfacee5
        # Prior to Vista SP1, there's no built-in way to programmatically
        # delete user profiles (except for delprof.exe). So try to delete
        # but warn if we fail
        raise e unless e.message.include?('80041010')

        Puppet.warning _("Cannot delete user profile for '%{sid}' prior to Vista SP1") % { sid: sid }
      end
    end
  end

  class Group < ADSIObject
    # https://msdn.microsoft.com/en-us/library/aa706021.aspx
    # IADsGroup interface
    @object_class = 'group'

    class << self
      def list_all
        Puppet::Util::Windows::ADSI.execquery('select name from win32_group where localaccount = "TRUE"')
      end

      def create(name)
        # Windows error 2224: The account already exists.
        raise Puppet::Error.new(_("Cannot create group if user '%{name}' exists.") % { name: name }) if Puppet::Util::Windows::ADSI::User.exists?(name)

        new(name, Puppet::Util::Windows::ADSI.create(name, @object_class))
      end
    end

    def add_member_sids(*sids)
      sids.each do |sid|
        native_object.Add(Puppet::Util::Windows::ADSI.sid_uri(sid))
      end
    end

    def remove_member_sids(*sids)
      sids.each do |sid|
        native_object.Remove(Puppet::Util::Windows::ADSI.sid_uri(sid))
      end
    end

    # returns Puppet::Util::Windows::SID::Principal[]
    # may contain objects that represent unresolvable SIDs
    # qualified account names are returned by calling #domain_account
    def members
      self.class.get_sids(native_object.Members)
    end
    alias member_sids members

    def set_members(desired_members, inclusive = true)
      return if desired_members.nil?

      current_hash = self.member_sids.to_h { |sid| [sid.sid, sid] }
      desired_hash = self.class.name_sid_hash(desired_members)

      # First we add all missing members
      unless desired_hash.empty?
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
  end
end
