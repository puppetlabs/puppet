require 'puppet/util/windows'
require 'win32/process'
require 'ffi'

module Puppet::Util::Windows::Process
  extend Puppet::Util::Windows::String
  extend FFI::Library

  WAIT_TIMEOUT = 0x102

  def execute(command, arguments, stdin, stdout, stderr)
    Process.create( :command_line => command, :startup_info => {:stdin => stdin, :stdout => stdout, :stderr => stderr}, :close_handles => false )
  end
  module_function :execute

  def wait_process(handle)
    while WaitForSingleObject(handle, 0) == WAIT_TIMEOUT
      sleep(1)
    end

    exit_status = FFI::MemoryPointer.new(:dword, 1)
    if GetExitCodeProcess(handle, exit_status) == FFI::WIN32_FALSE
      raise Puppet::Util::Windows::Error.new("Failed to get child process exit code")
    end
    exit_status = exit_status.read_dword

    # $CHILD_STATUS is not set when calling win32/process Process.create
    # and since it's read-only, we can't set it. But we can execute a
    # a shell that simply returns the desired exit status, which has the
    # desired effect.
    %x{#{ENV['COMSPEC']} /c exit #{exit_status}}

    exit_status
  end
  module_function :wait_process

  def get_current_process
    # this pseudo-handle does not require closing per MSDN docs
    GetCurrentProcess()
  end
  module_function :get_current_process

  def open_process_token(handle, desired_access)
    token_handle_ptr = FFI::MemoryPointer.new(:handle, 1)
    result = OpenProcessToken(handle, desired_access, token_handle_ptr)
    if result == FFI::WIN32_FALSE
      raise Puppet::Util::Windows::Error.new(
        "OpenProcessToken(#{handle}, #{desired_access.to_s(8)}, #{token_handle_ptr})")
    end

    begin
      yield token_handle = token_handle_ptr.read_handle
    ensure
      CloseHandle(token_handle)
    end
  end
  module_function :open_process_token

  def lookup_privilege_value(name, system_name = '')
    luid = FFI::MemoryPointer.new(LUID.size)
    result = LookupPrivilegeValueW(
      wide_string(system_name),
      wide_string(name.to_s),
      luid
      )

    return LUID.new(luid) if result != FFI::WIN32_FALSE
    raise Puppet::Util::Windows::Error.new(
      "LookupPrivilegeValue(#{system_name}, #{name}, #{luid})")
  end
  module_function :lookup_privilege_value

  def get_token_information(token_handle, token_information)
    # to determine buffer size
    return_length_ptr = FFI::MemoryPointer.new(:dword, 1)
    result = GetTokenInformation(token_handle, token_information, nil, 0, return_length_ptr)
    return_length = return_length_ptr.read_dword

    if return_length <= 0
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, nil, 0, #{return_length_ptr})")
    end

    # re-call API with properly sized buffer for all results
    token_information_buf = FFI::MemoryPointer.new(return_length)
    result = GetTokenInformation(token_handle, token_information,
      token_information_buf, return_length, return_length_ptr)

    if result == FFI::WIN32_FALSE
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, #{token_information_buf}, " +
          "#{return_length}, #{return_length_ptr})")
    end

    token_information_buf
  end
  module_function :get_token_information

  def parse_token_information_as_token_privileges(token_information_buf)
    raw_privileges = TOKEN_PRIVILEGES.new(token_information_buf)
    privileges = { :count => raw_privileges[:PrivilegeCount], :privileges => [] }

    offset = token_information_buf + TOKEN_PRIVILEGES.offset_of(:Privileges)
    privilege_ptr = FFI::Pointer.new(LUID_AND_ATTRIBUTES, offset)

    # extract each instance of LUID_AND_ATTRIBUTES
    0.upto(privileges[:count] - 1) do |i|
      privileges[:privileges] <<  LUID_AND_ATTRIBUTES.new(privilege_ptr[i])
    end

    privileges
  end
  module_function :parse_token_information_as_token_privileges

  def parse_token_information_as_token_elevation(token_information_buf)
    TOKEN_ELEVATION.new(token_information_buf)
  end
  module_function :parse_token_information_as_token_elevation

  TOKEN_ALL_ACCESS = 0xF01FF
  ERROR_NO_SUCH_PRIVILEGE = 1313
  def process_privilege_symlink?
    handle = get_current_process
    open_process_token(handle, TOKEN_ALL_ACCESS) do |token_handle|
      luid = lookup_privilege_value('SeCreateSymbolicLinkPrivilege')
      token_info = get_token_information(token_handle, :TokenPrivileges)
      token_privileges = parse_token_information_as_token_privileges(token_info)
      token_privileges[:privileges].any? { |p| p[:Luid].values == luid.values }
    end
  rescue Puppet::Util::Windows::Error => e
    if e.code == ERROR_NO_SUCH_PRIVILEGE
      false # pre-Vista
    else
      raise e
    end
  end
  module_function :process_privilege_symlink?

  TOKEN_QUERY = 0x0008
  # Returns whether or not the owner of the current process is running
  # with elevated security privileges.
  #
  # Only supported on Windows Vista or later.
  #
  def elevated_security?
    handle = get_current_process
    open_process_token(handle, TOKEN_QUERY) do |token_handle|
      token_info = get_token_information(token_handle, :TokenElevation)
      token_elevation = parse_token_information_as_token_elevation(token_info)
      # TokenIsElevated member of the TOKEN_ELEVATION struct
      token_elevation[:TokenIsElevated] != 0
    end
  rescue Puppet::Util::Windows::Error => e
    if e.code == ERROR_NO_SUCH_PRIVILEGE
      false # pre-Vista
    else
      raise e
    end
  ensure
    CloseHandle(handle)
  end
  module_function :elevated_security?


  ffi_convention :stdcall

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms687032(v=vs.85).aspx
  # DWORD WINAPI WaitForSingleObject(
  #   _In_  HANDLE hHandle,
  #   _In_  DWORD dwMilliseconds
  # );
  ffi_lib :kernel32
  attach_function_private :WaitForSingleObject,
    [:handle, :dword], :dword

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms683189(v=vs.85).aspx
  # BOOL WINAPI GetExitCodeProcess(
  #   _In_   HANDLE hProcess,
  #   _Out_  LPDWORD lpExitCode
  # );
  ffi_lib :kernel32
  attach_function_private :GetExitCodeProcess,
    [:handle, :lpdword], :win32_bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms683179(v=vs.85).aspx
  # HANDLE WINAPI GetCurrentProcess(void);
  ffi_lib :kernel32
  attach_function_private :GetCurrentProcess, [], :handle

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms724211(v=vs.85).aspx
  # BOOL WINAPI CloseHandle(
  #   _In_  HANDLE hObject
  # );
  ffi_lib :kernel32
  attach_function_private :CloseHandle, [:handle], :win32_bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379295(v=vs.85).aspx
  # BOOL WINAPI OpenProcessToken(
  #   _In_   HANDLE ProcessHandle,
  #   _In_   DWORD DesiredAccess,
  #   _Out_  PHANDLE TokenHandle
  # );
  ffi_lib :advapi32
  attach_function_private :OpenProcessToken,
    [:handle, :dword, :phandle], :win32_bool


  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379261(v=vs.85).aspx
  # typedef struct _LUID {
  #   DWORD LowPart;
  #   LONG  HighPart;
  # } LUID, *PLUID;
  class LUID < FFI::Struct
    layout :LowPart, :dword,
           :HighPart, :win32_long
  end

  # http://msdn.microsoft.com/en-us/library/Windows/desktop/aa379180(v=vs.85).aspx
  # BOOL WINAPI LookupPrivilegeValue(
  #   _In_opt_  LPCTSTR lpSystemName,
  #   _In_      LPCTSTR lpName,
  #   _Out_     PLUID lpLuid
  # );
  ffi_lib :advapi32
  attach_function_private :LookupPrivilegeValueW,
    [:lpcwstr, :lpcwstr, :pointer], :win32_bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379626(v=vs.85).aspx
  TOKEN_INFORMATION_CLASS = enum(
      :TokenUser, 1,
      :TokenGroups,
      :TokenPrivileges,
      :TokenOwner,
      :TokenPrimaryGroup,
      :TokenDefaultDacl,
      :TokenSource,
      :TokenType,
      :TokenImpersonationLevel,
      :TokenStatistics,
      :TokenRestrictedSids,
      :TokenSessionId,
      :TokenGroupsAndPrivileges,
      :TokenSessionReference,
      :TokenSandBoxInert,
      :TokenAuditPolicy,
      :TokenOrigin,
      :TokenElevationType,
      :TokenLinkedToken,
      :TokenElevation,
      :TokenHasRestrictions,
      :TokenAccessInformation,
      :TokenVirtualizationAllowed,
      :TokenVirtualizationEnabled,
      :TokenIntegrityLevel,
      :TokenUIAccess,
      :TokenMandatoryPolicy,
      :TokenLogonSid,
      :TokenIsAppContainer,
      :TokenCapabilities,
      :TokenAppContainerSid,
      :TokenAppContainerNumber,
      :TokenUserClaimAttributes,
      :TokenDeviceClaimAttributes,
      :TokenRestrictedUserClaimAttributes,
      :TokenRestrictedDeviceClaimAttributes,
      :TokenDeviceGroups,
      :TokenRestrictedDeviceGroups,
      :TokenSecurityAttributes,
      :TokenIsRestricted,
      :MaxTokenInfoClass
  )

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379263(v=vs.85).aspx
  # typedef struct _LUID_AND_ATTRIBUTES {
  #   LUID  Luid;
  #   DWORD Attributes;
  # } LUID_AND_ATTRIBUTES, *PLUID_AND_ATTRIBUTES;
  class LUID_AND_ATTRIBUTES < FFI::Struct
    layout :Luid, LUID,
           :Attributes, :dword
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379630(v=vs.85).aspx
  # typedef struct _TOKEN_PRIVILEGES {
  #   DWORD               PrivilegeCount;
  #   LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
  # } TOKEN_PRIVILEGES, *PTOKEN_PRIVILEGES;
  class TOKEN_PRIVILEGES < FFI::Struct
    layout :PrivilegeCount, :dword,
           :Privileges, [LUID_AND_ATTRIBUTES, 1]    # placeholder for offset
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/bb530717(v=vs.85).aspx
  # typedef struct _TOKEN_ELEVATION {
  #   DWORD TokenIsElevated;
  # } TOKEN_ELEVATION, *PTOKEN_ELEVATION;
  class TOKEN_ELEVATION < FFI::Struct
    layout :TokenIsElevated, :dword
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx
  # BOOL WINAPI GetTokenInformation(
  #   _In_       HANDLE TokenHandle,
  #   _In_       TOKEN_INFORMATION_CLASS TokenInformationClass,
  #   _Out_opt_  LPVOID TokenInformation,
  #   _In_       DWORD TokenInformationLength,
  #   _Out_      PDWORD ReturnLength
  # );
  ffi_lib :advapi32
  attach_function_private :GetTokenInformation,
    [:handle, TOKEN_INFORMATION_CLASS, :lpvoid, :dword, :pdword ], :win32_bool
end
