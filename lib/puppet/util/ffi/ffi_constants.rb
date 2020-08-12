# require 'puppet/util/ffi'
module Puppet::Util::FFI
  module FFIConstants

  # require 'ffi'
  # extend FFI::Library

  # # # PROCESS_monkey 


  # # # Priority constants
  # # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass
  # # ABOVE_NORMAL_PRIORITY_CLASS = 0x0008000
  # # BELOW_NORMAL_PRIORITY_CLASS = 0x0004000
  # # HIGH_PRIORITY_CLASS         = 0x0000080
  # # IDLE_PRIORITY_CLASS         = 0x0000040
  # # NORMAL_PRIORITY_CLASS       = 0x0000020
  # # REALTIME_PRIORITY_CLASS     = 0x0000010

  # # # Process Access Rights
  # # # https://docs.microsoft.com/en-us/windows/win32/procthread/process-security-and-access-rights
  # # PROCESS_TERMINATE         = 0x00000001
  # # PROCESS_SET_INFORMATION   = 0x00000200
  # # PROCESS_QUERY_INFORMATION = 0x00000400
  # # PROCESS_ALL_ACCESS        = 0x001F0FFF
  # # PROCESS_VM_READ           = 0x00000010

  # # # Process creation flags
  # # # https://docs.microsoft.com/en-us/windows/win32/procthread/process-creation-flags
  # # CREATE_BREAKAWAY_FROM_JOB        = 0x01000000
  # # CREATE_DEFAULT_ERROR_MODE        = 0x04000000
  # # CREATE_NEW_CONSOLE               = 0x00000010
  # # CREATE_NEW_PROCESS_GROUP         = 0x00000200
  # # CREATE_NO_WINDOW                 = 0x08000000
  # # CREATE_PROTECTED_PROCESS         = 0x00040000
  # # CREATE_PRESERVE_CODE_AUTHZ_LEVEL = 0x02000000
  # # CREATE_SEPARATE_WOW_VDM          = 0x00000800
  # # CREATE_SHARED_WOW_VDM            = 0x00001000
  # # CREATE_SUSPENDED                 = 0x00000004
  # # CREATE_UNICODE_ENVIRONMENT       = 0x00000400
  # # DEBUG_ONLY_THIS_PROCESS          = 0x00000002
  # # DEBUG_PROCESS                    = 0x00000001
  # # DETACHED_PROCESS                 = 0x00000008
  # # INHERIT_PARENT_AFFINITY          = 0x00010000

  # # # Logon options
  # # LOGON_WITH_PROFILE        = 0x00000001

  # # # STARTUPINFOA constants
  # # # https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfoa
  # # STARTF_USESTDHANDLES    = 0x00000100

  # # # Miscellaneous
  # # HANDLE_FLAG_INHERIT     = 0x00000001
  # # SEM_FAILCRITICALERRORS  = 0x00000001
  # # SEM_NOGPFAULTERRORBOX   = 0x00000002

  # # # Error constants
  # # INVALID_HANDLE_VALUE = FFI::Pointer.new(-1).address



  # # # --------------------------


  # # #PROCESS

  # # # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379626(v=vs.85).aspx
  # # TOKEN_INFORMATION_CLASS = enum(
  # #     :TokenUser, 1,
  # #     :TokenGroups,
  # #     :TokenPrivileges,
  # #     :TokenOwner,
  # #     :TokenPrimaryGroup,
  # #     :TokenDefaultDacl,
  # #     :TokenSource,
  # #     :TokenType,
  # #     :TokenImpersonationLevel,
  # #     :TokenStatistics,
  # #     :TokenRestrictedSids,
  # #     :TokenSessionId,
  # #     :TokenGroupsAndPrivileges,
  # #     :TokenSessionReference,
  # #     :TokenSandBoxInert,
  # #     :TokenAuditPolicy,
  # #     :TokenOrigin,
  # #     :TokenElevationType,
  # #     :TokenLinkedToken,
  # #     :TokenElevation,
  # #     :TokenHasRestrictions,
  # #     :TokenAccessInformation,
  # #     :TokenVirtualizationAllowed,
  # #     :TokenVirtualizationEnabled,
  # #     :TokenIntegrityLevel,
  # #     :TokenUIAccess,
  # #     :TokenMandatoryPolicy,
  # #     :TokenLogonSid,
  # #     :TokenIsAppContainer,
  # #     :TokenCapabilities,
  # #     :TokenAppContainerSid,
  # #     :TokenAppContainerNumber,
  # #     :TokenUserClaimAttributes,
  # #     :TokenDeviceClaimAttributes,
  # #     :TokenRestrictedUserClaimAttributes,
  # #     :TokenRestrictedDeviceClaimAttributes,
  # #     :TokenDeviceGroups,
  # #     :TokenRestrictedDeviceGroups,
  # #     :TokenSecurityAttributes,
  # #     :TokenIsRestricted,
  # #     :MaxTokenInfoClass
  # # )

end
end