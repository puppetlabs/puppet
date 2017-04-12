require 'puppet/util/windows'

require 'facter'
require 'ffi'

module Puppet::Util::Windows::User
  extend Puppet::Util::Windows::String
  extend FFI::Library

  def admin?
    elevated_supported = Puppet::Util::Windows::Process.supports_elevated_security?

    # if Vista or later, check for unrestricted process token
    return Puppet::Util::Windows::Process.elevated_security? if elevated_supported

    # otherwise 2003 or less
    check_token_membership
  end
  module_function :admin?


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
          raise Puppet::Util::Windows::Error.new(_("Failed to create administrators SID"))
        end
      end

      if IsValidSid(sid_pointer) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new(_("Invalid SID"))
      end

      FFI::MemoryPointer.new(:win32_bool, 1) do |ismember_pointer|
        if CheckTokenMembership(FFI::Pointer::NULL_HANDLE, sid_pointer, ismember_pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to check membership"))
        end

        # Is administrators SID enabled in calling thread's access token?
        is_admin = ismember_pointer.read_win32_bool
      end
    end

    is_admin
  end
  module_function :check_token_membership

  def password_is?(name, password)
    begin
      logon_user(name, password) { |token| }
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

  def logon_user(name, password, &block)
    fLOGON32_LOGON_NETWORK = 3
    fLOGON32_PROVIDER_DEFAULT = 0

    token = nil
    begin
      FFI::MemoryPointer.new(:handle, 1) do |token_pointer|
        if LogonUserW(wide_string(name), wide_string('.'), password.nil? ? FFI::Pointer::NULL : wide_string(password),
            fLOGON32_LOGON_NETWORK, fLOGON32_PROVIDER_DEFAULT, token_pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to logon user %{name}") % { name: name.inspect })
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

  def load_profile(user, password)
    logon_user(user, password) do |token|
      FFI::MemoryPointer.from_string_to_wide_string(user) do |lpUserName|
        pi = PROFILEINFO.new
        pi[:dwSize] = PROFILEINFO.size
        pi[:dwFlags] = 1 # PI_NOUI - prevents display of profile error msgs
        pi[:lpUserName] = lpUserName

        # Load the profile. Since it doesn't exist, it will be created
        if LoadUserProfileW(token, pi.pointer) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to load user profile %{user}") % { user: user.inspect })
        end

        Puppet.debug("Loaded profile for #{user}")

        if UnloadUserProfile(token, pi[:hProfile]) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to unload user profile %{user}") % { user: user.inspect })
        end
      end
    end
  end
  module_function :load_profile

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
end
