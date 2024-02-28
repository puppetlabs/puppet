# frozen_string_literal: true

require_relative '../../../puppet/util/windows'

require 'ffi'

module Puppet::Util::Windows::User
  extend Puppet::Util::Windows::String
  extend FFI::Library

  def admin?
    return false unless check_token_membership

    # if Vista or later, check for unrestricted process token
    elevated_supported = Puppet::Util::Windows::Process.supports_elevated_security?
    return elevated_supported ? Puppet::Util::Windows::Process.elevated_security? : true
  end
  module_function :admin?

  # The name of the account in all locales is `LocalSystem`. `.\LocalSystem` or `ComputerName\LocalSystem' can also be used.
  # This account is not recognized by the security subsystem, so you cannot specify its name in a call to the `LookupAccountName` function.
  # https://docs.microsoft.com/en-us/windows/win32/services/localsystem-account
  def localsystem?(name)
    ["LocalSystem", ".\\LocalSystem", "#{Puppet::Util::Windows::ADSI.computer_name}\\LocalSystem"].any? { |s| s.casecmp(name) == 0 }
  end
  module_function :localsystem?

  # Check if a given user is one of the default system accounts
  # These accounts do not have a password and all checks done through logon attempt will fail
  # https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/local-accounts#default-local-system-accounts
  def default_system_account?(name)
    user_sid = Puppet::Util::Windows::SID.name_to_sid(name)
    [Puppet::Util::Windows::SID::LocalSystem, Puppet::Util::Windows::SID::NtLocal, Puppet::Util::Windows::SID::NtNetwork].include?(user_sid)
  end
  module_function :default_system_account?

  # https://msdn.microsoft.com/en-us/library/windows/desktop/ee207397(v=vs.85).aspx
  SECURITY_MAX_SID_SIZE = 68

  # https://msdn.microsoft.com/en-us/library/windows/desktop/ms681385(v=vs.85).aspx
  # These error codes indicate successful authentication but failure to
  # logon for a separate reason
  ERROR_ACCOUNT_RESTRICTION = 1327
  ERROR_INVALID_LOGON_HOURS = 1328
  ERROR_INVALID_WORKSTATION = 1329
  ERROR_ACCOUNT_DISABLED    = 1331

  def check_token_membership
    is_admin = false
    FFI::MemoryPointer.new(:byte, SECURITY_MAX_SID_SIZE) do |sid_pointer|
      FFI::MemoryPointer.new(:dword, 1) do |size_pointer|
        size_pointer.write_uint32(SECURITY_MAX_SID_SIZE)

        if CreateWellKnownSid(:WinBuiltinAdministratorsSid, FFI::Pointer::NULL, sid_pointer, size_pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error, _("Failed to create administrators SID")
        end
      end

      if IsValidSid(sid_pointer) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error, _("Invalid SID")
      end

      FFI::MemoryPointer.new(:win32_bool, 1) do |ismember_pointer|
        if CheckTokenMembership(FFI::Pointer::NULL_HANDLE, sid_pointer, ismember_pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error, _("Failed to check membership")
        end

        # Is administrators SID enabled in calling thread's access token?
        is_admin = ismember_pointer.read_win32_bool
      end
    end

    is_admin
  end
  module_function :check_token_membership

  def password_is?(name, password, domain = '.')
    begin
      logon_user(name, password, domain) { |token| }
    rescue Puppet::Util::Windows::Error => detail
      authenticated_error_codes = Set[
        ERROR_ACCOUNT_RESTRICTION,
        ERROR_INVALID_LOGON_HOURS,
        ERROR_INVALID_WORKSTATION,
        ERROR_ACCOUNT_DISABLED,
      ]

      return authenticated_error_codes.include?(detail.code)
    end
  end
  module_function :password_is?

  def logon_user(name, password, domain = '.', &block)
    fLOGON32_PROVIDER_DEFAULT = 0
    fLOGON32_LOGON_INTERACTIVE = 2
    fLOGON32_LOGON_NETWORK = 3

    token = nil
    begin
      FFI::MemoryPointer.new(:handle, 1) do |token_pointer|
        # try logon using network else try logon using interactive mode
        if logon_user_by_logon_type(name, domain, password, fLOGON32_LOGON_NETWORK, fLOGON32_PROVIDER_DEFAULT, token_pointer) == FFI::WIN32_FALSE
          if logon_user_by_logon_type(name, domain, password, fLOGON32_LOGON_INTERACTIVE, fLOGON32_PROVIDER_DEFAULT, token_pointer) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error, _("Failed to logon user %{name}") % { name: name.inspect }
          end
        end

        yield token = token_pointer.read_handle
      end
    ensure
      FFI::WIN32.CloseHandle(token) if token
    end

    # token has been closed by this point
    true
  end
  module_function :logon_user

  def self.logon_user_by_logon_type(name, domain, password, logon_type, logon_provider, token)
    LogonUserW(wide_string(name), wide_string(domain), password.nil? ? FFI::Pointer::NULL : wide_string(password), logon_type, logon_provider, token)
  end

  private_class_method :logon_user_by_logon_type

  def load_profile(user, password)
    logon_user(user, password) do |token|
      FFI::MemoryPointer.from_string_to_wide_string(user) do |lpUserName|
        pi = PROFILEINFO.new
        pi[:dwSize] = PROFILEINFO.size
        pi[:dwFlags] = 1 # PI_NOUI - prevents display of profile error msgs
        pi[:lpUserName] = lpUserName

        # Load the profile. Since it doesn't exist, it will be created
        if LoadUserProfileW(token, pi.pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error, _("Failed to load user profile %{user}") % { user: user.inspect }
        end

        Puppet.debug("Loaded profile for #{user}")

        if UnloadUserProfile(token, pi[:hProfile]) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error, _("Failed to unload user profile %{user}") % { user: user.inspect }
        end
      end
    end
  end
  module_function :load_profile

  def get_rights(name)
    user_info = Puppet::Util::Windows::SID.name_to_principal(name.sub(/^\.\\/, "#{Puppet::Util::Windows::ADSI.computer_name}\\"))
    return "" unless user_info

    rights = []
    rights_pointer = FFI::MemoryPointer.new(:pointer)
    number_of_rights = FFI::MemoryPointer.new(:ulong)
    sid_pointer = FFI::MemoryPointer.new(:byte, user_info.sid_bytes.length).write_array_of_uchar(user_info.sid_bytes)

    new_lsa_policy_handle do |policy_handle|
      result = LsaEnumerateAccountRights(policy_handle.read_pointer, sid_pointer, rights_pointer, number_of_rights)
      check_lsa_nt_status_and_raise_failures(result, "LsaEnumerateAccountRights")
    end

    number_of_rights.read_ulong.times do |index|
      right = LSA_UNICODE_STRING.new(rights_pointer.read_pointer + index * LSA_UNICODE_STRING.size)
      rights << right[:Buffer].read_arbitrary_wide_string_up_to
    end

    result = LsaFreeMemory(rights_pointer.read_pointer)
    check_lsa_nt_status_and_raise_failures(result, "LsaFreeMemory")

    rights.join(",")
  end
  module_function :get_rights

  def set_rights(name, rights)
    rights_pointer = new_lsa_unicode_strings_pointer(rights)
    user_info = Puppet::Util::Windows::SID.name_to_principal(name.sub(/^\.\\/, "#{Puppet::Util::Windows::ADSI.computer_name}\\"))
    sid_pointer = FFI::MemoryPointer.new(:byte, user_info.sid_bytes.length).write_array_of_uchar(user_info.sid_bytes)

    new_lsa_policy_handle do |policy_handle|
      result = LsaAddAccountRights(policy_handle.read_pointer, sid_pointer, rights_pointer, rights.size)
      check_lsa_nt_status_and_raise_failures(result, "LsaAddAccountRights")
    end
  end
  module_function :set_rights

  def remove_rights(name, rights)
    rights_pointer = new_lsa_unicode_strings_pointer(rights)
    user_info = Puppet::Util::Windows::SID.name_to_principal(name.sub(/^\.\\/, "#{Puppet::Util::Windows::ADSI.computer_name}\\"))
    sid_pointer = FFI::MemoryPointer.new(:byte, user_info.sid_bytes.length).write_array_of_uchar(user_info.sid_bytes)

    new_lsa_policy_handle do |policy_handle|
      result = LsaRemoveAccountRights(policy_handle.read_pointer, sid_pointer, false, rights_pointer, rights.size)
      check_lsa_nt_status_and_raise_failures(result, "LsaRemoveAccountRights")
    end
  end
  module_function :remove_rights

  # ACCESS_MASK flags for Policy Objects
  # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-lsad/b61b7268-987a-420b-84f9-6c75f8dc8558
  POLICY_VIEW_LOCAL_INFORMATION   = 0x00000001
  POLICY_VIEW_AUDIT_INFORMATION   = 0x00000002
  POLICY_GET_PRIVATE_INFORMATION  = 0x00000004
  POLICY_TRUST_ADMIN              = 0x00000008
  POLICY_CREATE_ACCOUNT           = 0x00000010
  POLICY_CREATE_SECRET            = 0x00000020
  POLICY_CREATE_PRIVILEGE         = 0x00000040
  POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080
  POLICY_SET_AUDIT_REQUIREMENTS   = 0x00000100
  POLICY_AUDIT_LOG_ADMIN          = 0x00000200
  POLICY_SERVER_ADMIN             = 0x00000400
  POLICY_LOOKUP_NAMES             = 0x00000800
  POLICY_NOTIFICATION             = 0x00001000

  def self.new_lsa_policy_handle
    access = 0
    access |= POLICY_LOOKUP_NAMES
    access |= POLICY_CREATE_ACCOUNT
    policy_handle = FFI::MemoryPointer.new(:pointer)

    result = LsaOpenPolicy(nil, LSA_OBJECT_ATTRIBUTES.new, access, policy_handle)
    check_lsa_nt_status_and_raise_failures(result, "LsaOpenPolicy")

    begin
      yield policy_handle
    ensure
      result = LsaClose(policy_handle.read_pointer)
      check_lsa_nt_status_and_raise_failures(result, "LsaClose")
    end
  end
  private_class_method :new_lsa_policy_handle

  def self.new_lsa_unicode_strings_pointer(strings)
    lsa_unicode_strings_pointer = FFI::MemoryPointer.new(LSA_UNICODE_STRING, strings.size)

    strings.each_with_index do |string, index|
      lsa_string = LSA_UNICODE_STRING.new(lsa_unicode_strings_pointer + index * LSA_UNICODE_STRING.size)
      lsa_string[:Buffer] = FFI::MemoryPointer.from_string(wide_string(string))
      lsa_string[:Length] = string.length * 2
      lsa_string[:MaximumLength] = lsa_string[:Length] + 2
    end

    lsa_unicode_strings_pointer
  end
  private_class_method :new_lsa_unicode_strings_pointer

  # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/18d8fbe8-a967-4f1c-ae50-99ca8e491d2d
  def self.check_lsa_nt_status_and_raise_failures(status, method_name)
    error_code = LsaNtStatusToWinError(status)

    error_reason = case error_code.to_s(16)
                   when '0' # ERROR_SUCCESS
                     return # Method call succeded
                   when '2' # ERROR_FILE_NOT_FOUND
                     return # No rights/privilleges assigned to given user
                   when '5' # ERROR_ACCESS_DENIED
                     "Access is denied. Please make sure that puppet is running as administrator."
                   when '521' # ERROR_NO_SUCH_PRIVILEGE
                     "One or more of the given rights/privilleges are incorrect."
                   when '6ba' # RPC_S_SERVER_UNAVAILABLE
                     "The RPC server is unavailable or given domain name is invalid."
                   end

    raise Puppet::Error, "Calling `#{method_name}` returned 'Win32 Error Code 0x%08X'. #{error_reason}" % error_code
  end
  private_class_method :check_lsa_nt_status_and_raise_failures

  ffi_convention :stdcall

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa378184(v=vs.85).aspx
  # BOOL LogonUser(
  #   _In_      LPTSTR lpszUsername,
  #   _In_opt_  LPTSTR lpszDomain,
  #   _In_opt_  LPTSTR lpszPassword,
  #   _In_      DWORD dwLogonType,
  #   _In_      DWORD dwLogonProvider,
  #   _Out_     PHANDLE phToken
  # );
  ffi_lib :advapi32
  attach_function_private :LogonUserW,
                          [:lpwstr, :lpwstr, :lpwstr, :dword, :dword, :phandle], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/bb773378(v=vs.85).aspx
  # typedef struct _PROFILEINFO {
  #   DWORD  dwSize;
  #   DWORD  dwFlags;
  #   LPTSTR lpUserName;
  #   LPTSTR lpProfilePath;
  #   LPTSTR lpDefaultPath;
  #   LPTSTR lpServerName;
  #   LPTSTR lpPolicyPath;
  #   HANDLE hProfile;
  # } PROFILEINFO, *LPPROFILEINFO;
  # technically
  # NOTE: that for structs, buffer_* (lptstr alias) cannot be used
  class PROFILEINFO < FFI::Struct
    layout :dwSize, :dword,
           :dwFlags, :dword,
           :lpUserName, :pointer,
           :lpProfilePath, :pointer,
           :lpDefaultPath, :pointer,
           :lpServerName, :pointer,
           :lpPolicyPath, :pointer,
           :hProfile, :handle
  end

  # https://msdn.microsoft.com/en-us/library/windows/desktop/bb762281(v=vs.85).aspx
  # BOOL WINAPI LoadUserProfile(
  #   _In_     HANDLE hToken,
  #   _Inout_  LPPROFILEINFO lpProfileInfo
  # );
  ffi_lib :userenv
  attach_function_private :LoadUserProfileW,
                          [:handle, :pointer], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/bb762282(v=vs.85).aspx
  # BOOL WINAPI UnloadUserProfile(
  #   _In_  HANDLE hToken,
  #   _In_  HANDLE hProfile
  # );
  ffi_lib :userenv
  attach_function_private :UnloadUserProfile,
                          [:handle, :handle], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376389(v=vs.85).aspx
  # BOOL WINAPI CheckTokenMembership(
  #   _In_opt_  HANDLE TokenHandle,
  #   _In_      PSID SidToCheck,
  #   _Out_     PBOOL IsMember
  # );
  ffi_lib :advapi32
  attach_function_private :CheckTokenMembership,
                          [:handle, :pointer, :pbool], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379650(v=vs.85).aspx
  # rubocop:disable Layout/SpaceBeforeComma
  WELL_KNOWN_SID_TYPE = enum(
    :WinNullSid                                   , 0,
    :WinWorldSid                                  , 1,
    :WinLocalSid                                  , 2,
    :WinCreatorOwnerSid                           , 3,
    :WinCreatorGroupSid                           , 4,
    :WinCreatorOwnerServerSid                     , 5,
    :WinCreatorGroupServerSid                     , 6,
    :WinNtAuthoritySid                            , 7,
    :WinDialupSid                                 , 8,
    :WinNetworkSid                                , 9,
    :WinBatchSid                                  , 10,
    :WinInteractiveSid                            , 11,
    :WinServiceSid                                , 12,
    :WinAnonymousSid                              , 13,
    :WinProxySid                                  , 14,
    :WinEnterpriseControllersSid                  , 15,
    :WinSelfSid                                   , 16,
    :WinAuthenticatedUserSid                      , 17,
    :WinRestrictedCodeSid                         , 18,
    :WinTerminalServerSid                         , 19,
    :WinRemoteLogonIdSid                          , 20,
    :WinLogonIdsSid                               , 21,
    :WinLocalSystemSid                            , 22,
    :WinLocalServiceSid                           , 23,
    :WinNetworkServiceSid                         , 24,
    :WinBuiltinDomainSid                          , 25,
    :WinBuiltinAdministratorsSid                  , 26,
    :WinBuiltinUsersSid                           , 27,
    :WinBuiltinGuestsSid                          , 28,
    :WinBuiltinPowerUsersSid                      , 29,
    :WinBuiltinAccountOperatorsSid                , 30,
    :WinBuiltinSystemOperatorsSid                 , 31,
    :WinBuiltinPrintOperatorsSid                  , 32,
    :WinBuiltinBackupOperatorsSid                 , 33,
    :WinBuiltinReplicatorSid                      , 34,
    :WinBuiltinPreWindows2000CompatibleAccessSid  , 35,
    :WinBuiltinRemoteDesktopUsersSid              , 36,
    :WinBuiltinNetworkConfigurationOperatorsSid   , 37,
    :WinAccountAdministratorSid                   , 38,
    :WinAccountGuestSid                           , 39,
    :WinAccountKrbtgtSid                          , 40,
    :WinAccountDomainAdminsSid                    , 41,
    :WinAccountDomainUsersSid                     , 42,
    :WinAccountDomainGuestsSid                    , 43,
    :WinAccountComputersSid                       , 44,
    :WinAccountControllersSid                     , 45,
    :WinAccountCertAdminsSid                      , 46,
    :WinAccountSchemaAdminsSid                    , 47,
    :WinAccountEnterpriseAdminsSid                , 48,
    :WinAccountPolicyAdminsSid                    , 49,
    :WinAccountRasAndIasServersSid                , 50,
    :WinNTLMAuthenticationSid                     , 51,
    :WinDigestAuthenticationSid                   , 52,
    :WinSChannelAuthenticationSid                 , 53,
    :WinThisOrganizationSid                       , 54,
    :WinOtherOrganizationSid                      , 55,
    :WinBuiltinIncomingForestTrustBuildersSid     , 56,
    :WinBuiltinPerfMonitoringUsersSid             , 57,
    :WinBuiltinPerfLoggingUsersSid                , 58,
    :WinBuiltinAuthorizationAccessSid             , 59,
    :WinBuiltinTerminalServerLicenseServersSid    , 60,
    :WinBuiltinDCOMUsersSid                       , 61,
    :WinBuiltinIUsersSid                          , 62,
    :WinIUserSid                                  , 63,
    :WinBuiltinCryptoOperatorsSid                 , 64,
    :WinUntrustedLabelSid                         , 65,
    :WinLowLabelSid                               , 66,
    :WinMediumLabelSid                            , 67,
    :WinHighLabelSid                              , 68,
    :WinSystemLabelSid                            , 69,
    :WinWriteRestrictedCodeSid                    , 70,
    :WinCreatorOwnerRightsSid                     , 71,
    :WinCacheablePrincipalsGroupSid               , 72,
    :WinNonCacheablePrincipalsGroupSid            , 73,
    :WinEnterpriseReadonlyControllersSid          , 74,
    :WinAccountReadonlyControllersSid             , 75,
    :WinBuiltinEventLogReadersGroup               , 76,
    :WinNewEnterpriseReadonlyControllersSid       , 77,
    :WinBuiltinCertSvcDComAccessGroup             , 78,
    :WinMediumPlusLabelSid                        , 79,
    :WinLocalLogonSid                             , 80,
    :WinConsoleLogonSid                           , 81,
    :WinThisOrganizationCertificateSid            , 82,
    :WinApplicationPackageAuthoritySid            , 83,
    :WinBuiltinAnyPackageSid                      , 84,
    :WinCapabilityInternetClientSid               , 85,
    :WinCapabilityInternetClientServerSid         , 86,
    :WinCapabilityPrivateNetworkClientServerSid   , 87,
    :WinCapabilityPicturesLibrarySid              , 88,
    :WinCapabilityVideosLibrarySid                , 89,
    :WinCapabilityMusicLibrarySid                 , 90,
    :WinCapabilityDocumentsLibrarySid             , 91,
    :WinCapabilitySharedUserCertificatesSid       , 92,
    :WinCapabilityEnterpriseAuthenticationSid     , 93,
    :WinCapabilityRemovableStorageSid             , 94
  )
  # rubocop:enable Layout/SpaceBeforeComma

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446585(v=vs.85).aspx
  # BOOL WINAPI CreateWellKnownSid(
  #   _In_       WELL_KNOWN_SID_TYPE WellKnownSidType,
  #   _In_opt_   PSID DomainSid,
  #   _Out_opt_  PSID pSid,
  #   _Inout_    DWORD *cbSid
  # );
  ffi_lib :advapi32
  attach_function_private :CreateWellKnownSid,
                          [WELL_KNOWN_SID_TYPE, :pointer, :pointer, :lpdword], :win32_bool

  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379151(v=vs.85).aspx
  # BOOL WINAPI IsValidSid(
  #   _In_  PSID pSid
  # );
  ffi_lib :advapi32
  attach_function_private :IsValidSid,
                          [:pointer], :win32_bool

  # https://docs.microsoft.com/en-us/windows/win32/api/lsalookup/ns-lsalookup-lsa_object_attributes
  # typedef struct _LSA_OBJECT_ATTRIBUTES {
  #   ULONG               Length;
  #   HANDLE              RootDirectory;
  #   PLSA_UNICODE_STRING ObjectName;
  #   ULONG               Attributes;
  #   PVOID               SecurityDescriptor;
  #   PVOID               SecurityQualityOfService;
  # } LSA_OBJECT_ATTRIBUTES, *PLSA_OBJECT_ATTRIBUTES;
  class LSA_OBJECT_ATTRIBUTES < FFI::Struct
    layout :Length, :ulong,
           :RootDirectory, :handle,
           :ObjectName, :plsa_unicode_string,
           :Attributes, :ulong,
           :SecurityDescriptor, :pvoid,
           :SecurityQualityOfService, :pvoid
  end

  # https://docs.microsoft.com/en-us/windows/win32/api/lsalookup/ns-lsalookup-lsa_unicode_string
  # typedef struct _LSA_UNICODE_STRING {
  #   USHORT Length;
  #   USHORT MaximumLength;
  #   PWSTR  Buffer;
  # } LSA_UNICODE_STRING, *PLSA_UNICODE_STRING;
  class LSA_UNICODE_STRING < FFI::Struct
    layout :Length, :ushort,
           :MaximumLength, :ushort,
           :Buffer, :pwstr
  end

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaenumerateaccountrights
  # https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/user-rights-assignment
  # NTSTATUS LsaEnumerateAccountRights(
  #   LSA_HANDLE          PolicyHandle,
  #   PSID                AccountSid,
  #   PLSA_UNICODE_STRING *UserRights,
  #   PULONG              CountOfRights
  # );
  ffi_lib :advapi32
  attach_function_private :LsaEnumerateAccountRights,
                          [:lsa_handle, :psid, :plsa_unicode_string, :pulong], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaaddaccountrights
  # NTSTATUS LsaAddAccountRights(
  #   LSA_HANDLE          PolicyHandle,
  #   PSID                AccountSid,
  #   PLSA_UNICODE_STRING UserRights,
  #   ULONG               CountOfRights
  # );
  ffi_lib :advapi32
  attach_function_private :LsaAddAccountRights,
                          [:lsa_handle, :psid, :plsa_unicode_string, :ulong], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaremoveaccountrights
  # NTSTATUS LsaRemoveAccountRights(
  #   LSA_HANDLE          PolicyHandle,
  #   PSID                AccountSid,
  #   BOOLEAN             AllRights,
  #   PLSA_UNICODE_STRING UserRights,
  #   ULONG               CountOfRights
  # );
  ffi_lib :advapi32
  attach_function_private :LsaRemoveAccountRights,
                          [:lsa_handle, :psid, :bool, :plsa_unicode_string, :ulong], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaopenpolicy
  # NTSTATUS LsaOpenPolicy(
  #   PLSA_UNICODE_STRING    SystemName,
  #   PLSA_OBJECT_ATTRIBUTES ObjectAttributes,
  #   ACCESS_MASK            DesiredAccess,
  #   PLSA_HANDLE            PolicyHandle
  # );
  ffi_lib :advapi32
  attach_function_private :LsaOpenPolicy,
                          [:plsa_unicode_string, :plsa_object_attributes, :access_mask, :plsa_handle], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaclose
  # NTSTATUS LsaClose(
  #   LSA_HANDLE ObjectHandle
  # );
  ffi_lib :advapi32
  attach_function_private :LsaClose,
                          [:lsa_handle], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsafreememory
  # NTSTATUS LsaFreeMemory(
  #   PVOID Buffer
  # );
  ffi_lib :advapi32
  attach_function_private :LsaFreeMemory,
                          [:pvoid], :ntstatus

  # https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsantstatustowinerror
  # ULONG LsaNtStatusToWinError(
  #   NTSTATUS Status
  # );
  ffi_lib :advapi32
  attach_function_private :LsaNtStatusToWinError,
                          [:ntstatus], :ulong
end
