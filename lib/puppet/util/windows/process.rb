require 'puppet/util/windows'
require 'windows/process'
require 'windows/handle'
require 'windows/synchronize'
require 'ffi'

module Puppet::Util::Windows::Process
  extend ::Windows::Process
  extend ::Windows::Handle
  extend ::Windows::Synchronize

  extend FFI::Library
  ffi_convention :stdcall

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms683179(v=vs.85).aspx
  # HANDLE WINAPI GetCurrentProcess(void);
  ffi_lib 'kernel32'
  attach_function_private :GetCurrentProcess, [], :handle

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms724211(v=vs.85).aspx
  # BOOL WINAPI CloseHandle(
  #   _In_  HANDLE hObject
  # );
  ffi_lib 'kernel32'
  attach_function_private :CloseHandle, [:handle], :bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379295(v=vs.85).aspx
  # BOOL WINAPI OpenProcessToken(
  #   _In_   HANDLE ProcessHandle,
  #   _In_   DWORD DesiredAccess,
  #   _Out_  PHANDLE TokenHandle
  # );
  ffi_lib 'advapi32'
  attach_function_private :OpenProcessToken,
    [:handle, :dword, :phandle], :bool


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
  ffi_lib 'advapi32'
  attach_function_private :LookupPrivilegeValueA,
    [:lpcstr, :lpcstr, :pointer], :bool

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

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx
  # BOOL WINAPI GetTokenInformation(
  #   _In_       HANDLE TokenHandle,
  #   _In_       TOKEN_INFORMATION_CLASS TokenInformationClass,
  #   _Out_opt_  LPVOID TokenInformation,
  #   _In_       DWORD TokenInformationLength,
  #   _Out_      PDWORD ReturnLength
  # );
  ffi_lib 'advapi32'
  attach_function_private :GetTokenInformation,
    [:handle, TOKEN_INFORMATION_CLASS, :lpvoid, :dword, :pdword ], :bool

  def execute(command, arguments, stdin, stdout, stderr)
    Process.create( :command_line => command, :startup_info => {:stdin => stdin, :stdout => stdout, :stderr => stderr}, :close_handles => false )
  end
  module_function :execute

  def wait_process(handle)
    while WaitForSingleObject(handle, 0) == Windows::Synchronize::WAIT_TIMEOUT
      sleep(1)
    end

    exit_status = [0].pack('L')
    unless GetExitCodeProcess(handle, exit_status)
      raise Puppet::Util::Windows::Error.new("Failed to get child process exit code")
    end
    exit_status = exit_status.unpack('L').first

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
    if !result
      raise Puppet::Util::Windows::Error.new(
        "OpenProcessToken(#{handle}, #{desired_access.to_s(8)}, #{token_handle_ptr})")
    end

    begin
      yield token_handle = token_handle_ptr.read_uint
    ensure
      CloseHandle(token_handle)
    end
  end
  module_function :open_process_token

  def lookup_privilege_value(name, system_name = '')
    luid = FFI::MemoryPointer.new(LUID.size)
    result = LookupPrivilegeValueA(
      system_name,
      name.to_s,
      luid
      )

    return LUID.new(luid) if result
    raise Puppet::Util::Windows::Error.new(
      "LookupPrivilegeValue(#{system_name}, #{name}, #{luid})")
  end
  module_function :lookup_privilege_value

  def get_token_information(token_handle, token_information)
    # to determine buffer size
    return_length_ptr = FFI::MemoryPointer.new(:dword, 1)
    result = GetTokenInformation(token_handle, token_information, nil, 0, return_length_ptr)
    return_length = return_length_ptr.read_uint

    if return_length <= 0
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, nil, 0, #{return_length_ptr})")
    end

    # re-call API with properly sized buffer for all results
    token_information_buf = FFI::MemoryPointer.new(return_length)
    result = GetTokenInformation(token_handle, token_information,
      token_information_buf, return_length, return_length_ptr)

    if !result
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, #{token_information_buf}, " +
          "#{return_length}, #{return_length_ptr})")
    end

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
  module_function :get_token_information

  TOKEN_ALL_ACCESS = 0xF01FF
  ERROR_NO_SUCH_PRIVILEGE = 1313
  def process_privilege_symlink?
    handle = get_current_process
    open_process_token(handle, TOKEN_ALL_ACCESS) do |token_handle|
      luid = lookup_privilege_value('SeCreateSymbolicLinkPrivilege')
      token_info = get_token_information(token_handle, :TokenPrivileges)
      token_info[:privileges].any? { |p| p[:Luid].values == luid.values }
    end
  rescue Puppet::Util::Windows::Error => e
    if e.code == ERROR_NO_SUCH_PRIVILEGE
      false # pre-Vista
    else
      raise e
    end
  end
  module_function :process_privilege_symlink?
end
