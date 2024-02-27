# frozen_string_literal: true

require_relative '../../../puppet/util/windows/monkey_patches/process'
require_relative '../../../puppet/ffi/windows'

module Puppet::Util::Windows::Process
  extend Puppet::FFI::Windows::Functions
  include Puppet::FFI::Windows::Structs
  extend Puppet::Util::Windows::String

  WAIT_TIMEOUT = 0x102
  WAIT_INTERVAL = 200
  # https://docs.microsoft.com/en-us/windows/desktop/ProcThread/process-creation-flags
  CREATE_NO_WINDOW = 0x08000000
  # https://docs.microsoft.com/en-us/windows/desktop/ProcThread/process-security-and-access-rights
  PROCESS_QUERY_INFORMATION = 0x0400
  # https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
  MAX_PATH_LENGTH = 32_767

  def execute(command, arguments, stdin, stdout, stderr)
    create_args = {
      :command_line => command,
      :startup_info => {
        :stdin => stdin,
        :stdout => stdout,
        :stderr => stderr
      },
      :close_handles => false,
    }
    if arguments[:suppress_window]
      create_args[:creation_flags] = CREATE_NO_WINDOW
    end
    if arguments[:cwd]
      create_args[:cwd] = arguments[:cwd]
    end
    Process.create(create_args)
  end
  module_function :execute

  def wait_process(handle)
    while WaitForSingleObject(handle, WAIT_INTERVAL) == WAIT_TIMEOUT
      sleep(0)
    end

    exit_status = -1
    FFI::MemoryPointer.new(:dword, 1) do |exit_status_ptr|
      if GetExitCodeProcess(handle, exit_status_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new(_("Failed to get child process exit code"))
      end

      exit_status = exit_status_ptr.read_dword

      # $CHILD_STATUS is not set when calling win32/process Process.create
      # and since it's read-only, we can't set it. But we can execute a
      # a shell that simply returns the desired exit status, which has the
      # desired effect.
      %x(#{ENV.fetch('COMSPEC', nil)} /c exit #{exit_status})
    end

    exit_status
  end
  module_function :wait_process

  def get_current_process
    # this pseudo-handle does not require closing per MSDN docs
    GetCurrentProcess()
  end
  module_function :get_current_process

  def open_process(desired_access, inherit_handle, process_id, &block)
    phandle = nil
    inherit = inherit_handle ? FFI::WIN32_TRUE : FFI::WIN32_FALSE
    begin
      phandle = OpenProcess(desired_access, inherit, process_id)
      if phandle == FFI::Pointer::NULL_HANDLE
        raise Puppet::Util::Windows::Error.new(
          "OpenProcess(#{desired_access.to_s(8)}, #{inherit}, #{process_id})"
        )
      end

      yield phandle
    ensure
      FFI::WIN32.CloseHandle(phandle) if phandle
    end

    # phandle has had CloseHandle called against it, so nothing to return
    nil
  end
  module_function :open_process

  def open_process_token(handle, desired_access, &block)
    token_handle = nil
    begin
      FFI::MemoryPointer.new(:handle, 1) do |token_handle_ptr|
        result = OpenProcessToken(handle, desired_access, token_handle_ptr)
        if result == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(
            "OpenProcessToken(#{handle}, #{desired_access.to_s(8)}, #{token_handle_ptr})"
          )
        end

        yield token_handle = token_handle_ptr.read_handle
      end

      token_handle
    ensure
      FFI::WIN32.CloseHandle(token_handle) if token_handle
    end

    # token_handle has had CloseHandle called against it, so nothing to return
    nil
  end
  module_function :open_process_token

  # Execute a block with the current process token
  def with_process_token(access, &block)
    handle = get_current_process
    open_process_token(handle, access) do |token_handle|
      yield token_handle
    end

    # all handles have been closed, so nothing to safely return
    nil
  end
  module_function :with_process_token

  def get_process_image_name_by_pid(pid)
    image_name = ''.dup

    Puppet::Util::Windows::Security.with_privilege(Puppet::Util::Windows::Security::SE_DEBUG_NAME) do
      open_process(PROCESS_QUERY_INFORMATION, false, pid) do |phandle|
        FFI::MemoryPointer.new(:dword, 1) do |exe_name_length_ptr|
          # UTF is 2 bytes/char:
          max_chars = MAX_PATH_LENGTH + 1
          exe_name_length_ptr.write_dword(max_chars)
          FFI::MemoryPointer.new(:wchar, max_chars) do |exe_name_ptr|
            use_win32_path_format = 0
            result = QueryFullProcessImageNameW(phandle, use_win32_path_format, exe_name_ptr, exe_name_length_ptr)
            if result == FFI::WIN32_FALSE
              raise Puppet::Util::Windows::Error.new(
                "QueryFullProcessImageNameW(phandle, #{use_win32_path_format}, " \
                "exe_name_ptr, #{max_chars}"
              )
            end
            image_name = exe_name_ptr.read_wide_string(exe_name_length_ptr.read_dword)
          end
        end
      end
    end

    image_name
  end
  module_function :get_process_image_name_by_pid

  def lookup_privilege_value(name, system_name = '', &block)
    FFI::MemoryPointer.new(LUID.size) do |luid_ptr|
      result = LookupPrivilegeValueW(
        wide_string(system_name),
        wide_string(name.to_s),
        luid_ptr
      )

      if result == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new(
          "LookupPrivilegeValue(#{system_name}, #{name}, #{luid_ptr})"
        )
      end

      yield LUID.new(luid_ptr)
    end

    # the underlying MemoryPointer for LUID is cleaned up by this point
    nil
  end
  module_function :lookup_privilege_value

  def get_token_information(token_handle, token_information, &block)
    # to determine buffer size
    FFI::MemoryPointer.new(:dword, 1) do |return_length_ptr|
      result = GetTokenInformation(token_handle, token_information, nil, 0, return_length_ptr)
      return_length = return_length_ptr.read_dword

      if return_length <= 0
        raise Puppet::Util::Windows::Error.new(
          "GetTokenInformation(#{token_handle}, #{token_information}, nil, 0, #{return_length_ptr})"
        )
      end

      # re-call API with properly sized buffer for all results
      FFI::MemoryPointer.new(return_length) do |token_information_buf|
        result = GetTokenInformation(token_handle, token_information,
                                     token_information_buf, return_length, return_length_ptr)

        if result == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(
            "GetTokenInformation(#{token_handle}, #{token_information}, #{token_information_buf}, " \
            "#{return_length}, #{return_length_ptr})"
          )
        end

        yield token_information_buf
      end
    end

    # GetTokenInformation buffer has been cleaned up by this point, nothing to return
    nil
  end
  module_function :get_token_information

  def parse_token_information_as_token_privileges(token_information_buf)
    raw_privileges = TOKEN_PRIVILEGES.new(token_information_buf)
    privileges = { :count => raw_privileges[:PrivilegeCount], :privileges => [] }

    offset = token_information_buf + TOKEN_PRIVILEGES.offset_of(:Privileges)
    privilege_ptr = FFI::Pointer.new(LUID_AND_ATTRIBUTES, offset)

    # extract each instance of LUID_AND_ATTRIBUTES
    0.upto(privileges[:count] - 1) do |i|
      privileges[:privileges] << LUID_AND_ATTRIBUTES.new(privilege_ptr[i])
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
    privilege_symlink = false
    handle = get_current_process
    open_process_token(handle, TOKEN_ALL_ACCESS) do |token_handle|
      lookup_privilege_value('SeCreateSymbolicLinkPrivilege') do |luid|
        get_token_information(token_handle, :TokenPrivileges) do |token_info|
          token_privileges = parse_token_information_as_token_privileges(token_info)
          privilege_symlink = token_privileges[:privileges].any? { |p| p[:Luid].values == luid.values }
        end
      end
    end

    privilege_symlink
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
    # default / pre-Vista
    elevated = false
    handle = nil

    begin
      handle = get_current_process
      open_process_token(handle, TOKEN_QUERY) do |token_handle|
        get_token_information(token_handle, :TokenElevation) do |token_info|
          token_elevation = parse_token_information_as_token_elevation(token_info)
          # TokenIsElevated member of the TOKEN_ELEVATION struct
          elevated = token_elevation[:TokenIsElevated] != 0
        end
      end

      elevated
    rescue Puppet::Util::Windows::Error => e
      raise e if e.code != ERROR_NO_SUCH_PRIVILEGE
    ensure
      FFI::WIN32.CloseHandle(handle) if handle
    end
  end
  module_function :elevated_security?

  def windows_major_version
    ver = 0

    FFI::MemoryPointer.new(OSVERSIONINFO.size) do |os_version_ptr|
      os_version = OSVERSIONINFO.new(os_version_ptr)
      os_version[:dwOSVersionInfoSize] = OSVERSIONINFO.size

      result = GetVersionExW(os_version_ptr)

      if result == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new(_("GetVersionEx failed"))
      end

      ver = os_version[:dwMajorVersion]
    end

    ver
  end
  module_function :windows_major_version

  # Returns a hash of the current environment variables encoded as UTF-8
  # The memory block returned from GetEnvironmentStringsW is double-null terminated and the vars are paired as below;
  # Var1=Value1\0
  # Var2=Value2\0
  # VarX=ValueX\0\0
  # Note - Some env variable names start with '=' and are excluded from the return value
  # Note - The env_ptr MUST be freed using the FreeEnvironmentStringsW function
  # Note - There is no technical limitation to the size of the environment block returned.
  #   However a practical limit of 64K is used as no single environment variable can exceed 32KB
  def get_environment_strings
    env_ptr = GetEnvironmentStringsW()

    # pass :invalid => :replace to the Ruby String#encode to use replacement characters
    pairs = env_ptr.read_arbitrary_wide_string_up_to(65_534, :double_null, { :invalid => :replace })
                   .split(?\x00)
                   .reject { |env_str| env_str.nil? || env_str.empty? || env_str[0] == '=' }
                   .reject do |env_str|
                     # reject any string containing the Unicode replacement character
                     if env_str.include?("\uFFFD")
                       Puppet.warning(_("Discarding environment variable %{string} which contains invalid bytes") % { string: env_str })
                       true
                     end
                   end
                   .map { |env_pair| env_pair.split('=', 2) }
    pairs.to_h
  ensure
    if env_ptr && !env_ptr.null?
      if FreeEnvironmentStringsW(env_ptr) == FFI::WIN32_FALSE
        Puppet.debug "FreeEnvironmentStringsW memory leak"
      end
    end
  end
  module_function :get_environment_strings

  def set_environment_variable(name, val)
    raise Puppet::Util::Windows::Error(_('environment variable name must not be nil or empty')) if !name || name.empty?

    FFI::MemoryPointer.from_string_to_wide_string(name) do |name_ptr|
      if val.nil?
        if SetEnvironmentVariableW(name_ptr, FFI::MemoryPointer::NULL) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new(_("Failed to remove environment variable: %{name}") % { name: name })
        end
      else
        FFI::MemoryPointer.from_string_to_wide_string(val) do |val_ptr|
          if SetEnvironmentVariableW(name_ptr, val_ptr) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new(_("Failed to set environment variable: %{name}") % { name: name })
          end
        end
      end
    end
  end
  module_function :set_environment_variable

  def get_system_default_ui_language
    GetSystemDefaultUILanguage()
  end
  module_function :get_system_default_ui_language

  # Returns whether or not the OS has the ability to set elevated
  # token information.
  #
  # Returns true on Windows Vista or later, otherwise false
  #
  def supports_elevated_security?
    windows_major_version >= 6
  end
  module_function :supports_elevated_security?
end
