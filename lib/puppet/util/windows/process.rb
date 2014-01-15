require 'puppet/util/windows'
require 'windows/process'
require 'windows/handle'
require 'windows/synchronize'

module Puppet::Util::Windows::Process
  extend ::Windows::Process
  extend ::Windows::Handle
  extend ::Windows::Synchronize

  module API
    require 'ffi'
    extend FFI::Library
    ffi_convention :stdcall

    ffi_lib 'kernel32'

    # http://msdn.microsoft.com/en-us/library/windows/desktop/ms683179(v=vs.85).aspx
    # HANDLE WINAPI GetCurrentProcess(void);
    attach_function :get_current_process, :GetCurrentProcess, [], :uint

    # BOOL WINAPI CloseHandle(
    #   _In_  HANDLE hObject
    # );
    attach_function :close_handle, :CloseHandle, [:uint], :bool

    ffi_lib 'advapi32'

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379295(v=vs.85).aspx
    # BOOL WINAPI OpenProcessToken(
    #   _In_   HANDLE ProcessHandle,
    #   _In_   DWORD DesiredAccess,
    #   _Out_  PHANDLE TokenHandle
    # );
    attach_function :open_process_token, :OpenProcessToken,
      [:uint, :uint, :pointer], :bool


    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379261(v=vs.85).aspx
    # typedef struct _LUID {
    #   DWORD LowPart;
    #   LONG  HighPart;
    # } LUID, *PLUID;
    class LUID < FFI::Struct
      layout :low_part, :uint,
             :high_part, :int
    end

    # http://msdn.microsoft.com/en-us/library/Windows/desktop/aa379180(v=vs.85).aspx
    # BOOL WINAPI LookupPrivilegeValue(
    #   _In_opt_  LPCTSTR lpSystemName,
    #   _In_      LPCTSTR lpName,
    #   _Out_     PLUID lpLuid
    # );
    attach_function :lookup_privilege_value, :LookupPrivilegeValueA,
      [:string, :string, :pointer], :bool

    Token_Information = enum(
        :token_user, 1,
        :token_groups,
        :token_privileges,
        :token_owner,
        :token_primary_group,
        :token_default_dacl,
        :token_source,
        :token_type,
        :token_impersonation_level,
        :token_statistics,
        :token_restricted_sids,
        :token_session_id,
        :token_groups_and_privileges,
        :token_session_reference,
        :token_sandbox_inert,
        :token_audit_policy,
        :token_origin,
        :token_elevation_type,
        :token_linked_token,
        :token_elevation,
        :token_has_restrictions,
        :token_access_information,
        :token_virtualization_allowed,
        :token_virtualization_enabled,
        :token_integrity_level,
        :token_ui_access,
        :token_mandatory_policy,
        :token_logon_sid,
        :max_token_info_class
      )

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379263(v=vs.85).aspx
    # typedef struct _LUID_AND_ATTRIBUTES {
    #   LUID  Luid;
    #   DWORD Attributes;
    # } LUID_AND_ATTRIBUTES, *PLUID_AND_ATTRIBUTES;
    class LUID_And_Attributes < FFI::Struct
      layout :luid, LUID,
             :attributes, :uint
    end

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa379630(v=vs.85).aspx
    # typedef struct _TOKEN_PRIVILEGES {
    #   DWORD               PrivilegeCount;
    #   LUID_AND_ATTRIBUTES Privileges[ANYSIZE_ARRAY];
    # } TOKEN_PRIVILEGES, *PTOKEN_PRIVILEGES;
    class Token_Privileges < FFI::Struct
      layout :privilege_count, :uint,
             :privileges, [LUID_And_Attributes, 1]    # placeholder for offset
    end

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa446671(v=vs.85).aspx
    # BOOL WINAPI GetTokenInformation(
    #   _In_       HANDLE TokenHandle,
    #   _In_       TOKEN_INFORMATION_CLASS TokenInformationClass,
    #   _Out_opt_  LPVOID TokenInformation,
    #   _In_       DWORD TokenInformationLength,
    #   _Out_      PDWORD ReturnLength
    # );
    attach_function :get_token_information, :GetTokenInformation,
      [:uint, Token_Information, :pointer, :uint, :pointer ], :bool
  end

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
    API.get_current_process
  end
  module_function :get_current_process

  def open_process_token(handle, desired_access)
    token_handle_ptr = FFI::MemoryPointer.new(:uint, 1)
    result = API.open_process_token(handle, desired_access, token_handle_ptr)
    if !result
      raise Puppet::Util::Windows::Error.new(
        "OpenProcessToken(#{handle}, #{desired_access.to_s(8)}, #{token_handle_ptr})")
    end

    begin
      yield token_handle = token_handle_ptr.read_uint
    ensure
      API.close_handle(token_handle)
    end
  end
  module_function :open_process_token

  def lookup_privilege_value(name, system_name = '')
    luid = FFI::MemoryPointer.new(API::LUID.size)
    result = API.lookup_privilege_value(
      system_name,
      name.to_s,
      luid
      )

    return API::LUID.new(luid) if result
    raise Puppet::Util::Windows::Error.new(
      "LookupPrivilegeValue(#{system_name}, #{name}, #{luid})")
  end
  module_function :lookup_privilege_value

  def get_token_information(token_handle, token_information)
    # to determine buffer size
    return_length_ptr = FFI::MemoryPointer.new(:uint, 1)
    result = API.get_token_information(token_handle, token_information, nil, 0, return_length_ptr)
    return_length = return_length_ptr.read_uint

    if return_length <= 0
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, nil, 0, #{return_length_ptr})")
    end

    # re-call API with properly sized buffer for all results
    token_information_buf = FFI::MemoryPointer.new(return_length)
    result = API.get_token_information(token_handle, token_information,
      token_information_buf, return_length, return_length_ptr)

    if !result
      raise Puppet::Util::Windows::Error.new(
        "GetTokenInformation(#{token_handle}, #{token_information}, #{token_information_buf}, " +
          "#{return_length}, #{return_length_ptr})")
    end

    raw_privileges = API::Token_Privileges.new(token_information_buf)
    privileges = { :count => raw_privileges[:privilege_count], :privileges => [] }

    offset = token_information_buf + API::Token_Privileges.offset_of(:privileges)
    privilege_ptr = FFI::Pointer.new(API::LUID_And_Attributes, offset)

    # extract each instance of LUID_And_Attributes
    0.upto(privileges[:count] - 1) do |i|
      privileges[:privileges] <<  API::LUID_And_Attributes.new(privilege_ptr[i])
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
      token_info = get_token_information(token_handle, :token_privileges)
      token_info[:privileges].any? { |p| p[:luid].values == luid.values }
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
