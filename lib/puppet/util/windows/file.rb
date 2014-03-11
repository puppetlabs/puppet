require 'puppet/util/windows'

module Puppet::Util::Windows::File
  require 'ffi'
  require 'windows/api'

  def replace_file(target, source)
    target_encoded = Puppet::Util::Windows::String.wide_string(target.to_s)
    source_encoded = Puppet::Util::Windows::String.wide_string(source.to_s)

    flags = 0x1
    backup_file = nil
    result = API.replace_file(
      target_encoded,
      source_encoded,
      backup_file,
      flags,
      0,
      0
    )

    return true if result
    raise Puppet::Util::Windows::Error.new("ReplaceFile(#{target}, #{source})")
  end
  module_function :replace_file

  MoveFileEx = Windows::API.new('MoveFileExW', 'PPL', 'B')
  def move_file_ex(source, target, flags = 0)
    result = MoveFileEx.call(Puppet::Util::Windows::String.wide_string(source.to_s),
                             Puppet::Util::Windows::String.wide_string(target.to_s),
                             flags)
    return true unless result == 0
    raise Puppet::Util::Windows::Error.
      new("MoveFileEx(#{source}, #{target}, #{flags.to_s(8)})")
  end
  module_function :move_file_ex

  module API
    extend FFI::Library
    ffi_lib 'kernel32'
    ffi_convention :stdcall

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa365512(v=vs.85).aspx
    # BOOL WINAPI ReplaceFile(
    #   _In_        LPCTSTR lpReplacedFileName,
    #   _In_        LPCTSTR lpReplacementFileName,
    #   _In_opt_    LPCTSTR lpBackupFileName,
    #   _In_        DWORD dwReplaceFlags - 0x1 REPLACEFILE_WRITE_THROUGH,
    #                                      0x2 REPLACEFILE_IGNORE_MERGE_ERRORS,
    #                                      0x4 REPLACEFILE_IGNORE_ACL_ERRORS
    #   _Reserved_  LPVOID lpExclude,
    #   _Reserved_  LPVOID lpReserved
    # );
    attach_function :replace_file, :ReplaceFileW,
      [:buffer_in, :buffer_in, :buffer_in, :uint, :uint, :uint], :bool

    # BOOLEAN WINAPI CreateSymbolicLink(
    #   _In_  LPTSTR lpSymlinkFileName, - symbolic link to be created
    #   _In_  LPTSTR lpTargetFileName, - name of target for symbolic link
    #   _In_  DWORD dwFlags - 0x0 target is a file, 0x1 target is a directory
    # );
    # rescue on Windows < 6.0 so that code doesn't explode
    begin
      attach_function :create_symbolic_link, :CreateSymbolicLinkW,
        [:buffer_in, :buffer_in, :uint], :bool
    rescue LoadError
    end

    # DWORD WINAPI GetFileAttributes(
    #   _In_  LPCTSTR lpFileName
    # );
    attach_function :get_file_attributes, :GetFileAttributesW,
      [:buffer_in], :uint

    # HANDLE WINAPI CreateFile(
    #   _In_      LPCTSTR lpFileName,
    #   _In_      DWORD dwDesiredAccess,
    #   _In_      DWORD dwShareMode,
    #   _In_opt_  LPSECURITY_ATTRIBUTES lpSecurityAttributes,
    #   _In_      DWORD dwCreationDisposition,
    #   _In_      DWORD dwFlagsAndAttributes,
    #   _In_opt_  HANDLE hTemplateFile
    # );
    attach_function :create_file, :CreateFileW,
      [:buffer_in, :uint, :uint, :pointer, :uint, :uint, :uint], :uint

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa363216(v=vs.85).aspx
    # BOOL WINAPI DeviceIoControl(
    #   _In_         HANDLE hDevice,
    #   _In_         DWORD dwIoControlCode,
    #   _In_opt_     LPVOID lpInBuffer,
    #   _In_         DWORD nInBufferSize,
    #   _Out_opt_    LPVOID lpOutBuffer,
    #   _In_         DWORD nOutBufferSize,
    #   _Out_opt_    LPDWORD lpBytesReturned,
    #   _Inout_opt_  LPOVERLAPPED lpOverlapped
    # );
    attach_function :device_io_control, :DeviceIoControl,
      [:uint, :uint, :pointer, :uint, :pointer, :uint, :pointer, :pointer], :bool

    MAXIMUM_REPARSE_DATA_BUFFER_SIZE = 16384

    # REPARSE_DATA_BUFFER
    # http://msdn.microsoft.com/en-us/library/cc232006.aspx
    # http://msdn.microsoft.com/en-us/library/windows/hardware/ff552012(v=vs.85).aspx
    # struct is always MAXIMUM_REPARSE_DATA_BUFFER_SIZE bytes
    class ReparseDataBuffer < FFI::Struct
      layout :reparse_tag, :uint,
             :reparse_data_length, :ushort,
             :reserved, :ushort,
             :substitute_name_offset, :ushort,
             :substitute_name_length, :ushort,
             :print_name_offset, :ushort,
             :print_name_length, :ushort,
             :flags, :uint,
             # max less above fields dword / uint 4 bytes, ushort 2 bytes
             :path_buffer, [:uchar, MAXIMUM_REPARSE_DATA_BUFFER_SIZE - 20]
    end

    # BOOL WINAPI CloseHandle(
    #   _In_  HANDLE hObject
    # );
    attach_function :close_handle, :CloseHandle, [:uint], :bool
  end

  def symlink(target, symlink)
    flags = File.directory?(target) ? 0x1 : 0x0
    result = API.create_symbolic_link(Puppet::Util::Windows::String.wide_string(symlink.to_s),
      Puppet::Util::Windows::String.wide_string(target.to_s), flags)
    return true if result
    raise Puppet::Util::Windows::Error.new(
      "CreateSymbolicLink(#{symlink}, #{target}, #{flags.to_s(8)})")
  end
  module_function :symlink

  INVALID_FILE_ATTRIBUTES = 0xFFFFFFFF #define INVALID_FILE_ATTRIBUTES (DWORD (-1))
  def self.get_file_attributes(file_name)
    result = API.get_file_attributes(Puppet::Util::Windows::String.wide_string(file_name.to_s))
    return result unless result == INVALID_FILE_ATTRIBUTES
    raise Puppet::Util::Windows::Error.new("GetFileAttributes(#{file_name})")
  end

  INVALID_HANDLE_VALUE = -1 #define INVALID_HANDLE_VALUE ((HANDLE)(LONG_PTR)-1)
  def self.create_file(file_name, desired_access, share_mode, security_attributes,
    creation_disposition, flags_and_attributes, template_file_handle)

    result = API.create_file(Puppet::Util::Windows::String.wide_string(file_name.to_s),
      desired_access, share_mode, security_attributes, creation_disposition,
      flags_and_attributes, template_file_handle)

    return result unless result == INVALID_HANDLE_VALUE
    raise Puppet::Util::Windows::Error.new(
      "CreateFile(#{file_name}, #{desired_access.to_s(8)}, #{share_mode.to_s(8)}, " +
        "#{security_attributes}, #{creation_disposition.to_s(8)}, " +
        "#{flags_and_attributes.to_s(8)}, #{template_file_handle})")
  end

  def self.device_io_control(handle, io_control_code, in_buffer = nil, out_buffer = nil)
    if out_buffer.nil?
      raise Puppet::Util::Windows::Error.new("out_buffer is required")
    end

    result = API.device_io_control(
      handle,
      io_control_code,
      in_buffer, in_buffer.nil? ? 0 : in_buffer.size,
      out_buffer, out_buffer.size,
      FFI::MemoryPointer.new(:uint, 1),
      nil
    )

    return out_buffer if result
    raise Puppet::Util::Windows::Error.new(
      "DeviceIoControl(#{handle}, #{io_control_code}, " +
      "#{in_buffer}, #{in_buffer ? in_buffer.size : ''}, " +
      "#{out_buffer}, #{out_buffer ? out_buffer.size : ''}")
  end

  FILE_ATTRIBUTE_REPARSE_POINT = 0x400
  def symlink?(file_name)
    begin
      attributes = get_file_attributes(file_name)
      (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == FILE_ATTRIBUTE_REPARSE_POINT
    rescue
      # raised INVALID_FILE_ATTRIBUTES is equivalent to file not found
      false
    end
  end
  module_function :symlink?

  GENERIC_READ                  = 0x80000000
  FILE_SHARE_READ               = 1
  OPEN_EXISTING                 = 3
  FILE_FLAG_OPEN_REPARSE_POINT  = 0x00200000
  FILE_FLAG_BACKUP_SEMANTICS    = 0x02000000

  def self.open_symlink(link_name)
    begin
      yield handle = create_file(
      Puppet::Util::Windows::String.wide_string(link_name.to_s),
      GENERIC_READ,
      FILE_SHARE_READ,
      nil, # security_attributes
      OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
      0) # template_file
    ensure
      API.close_handle(handle) if handle
    end
  end

  def readlink(link_name)
    open_symlink(link_name) do |handle|
      resolve_symlink(handle)
    end
  end
  module_function :readlink

  def stat(file_name)
    file_name = file_name.to_s # accomodate PathName or String
    stat = File.stat(file_name)
    singleton_class = class << stat; self; end
    target_path = file_name

    if symlink?(file_name)
      target_path = readlink(file_name)
      link_ftype = File.stat(target_path).ftype

      # sigh, monkey patch instance method for instance, and close over link_ftype
      singleton_class.send(:define_method, :ftype) do
        link_ftype
      end
    end

    singleton_class.send(:define_method, :mode) do
      Puppet::Util::Windows::Security.get_mode(target_path)
    end

    stat
  end
  module_function :stat

  def lstat(file_name)
    file_name = file_name.to_s # accomodate PathName or String
    # monkey'ing around!
    stat = File.lstat(file_name)

    singleton_class = class << stat; self; end
    singleton_class.send(:define_method, :mode) do
      Puppet::Util::Windows::Security.get_mode(file_name)
    end

    if symlink?(file_name)
      def stat.ftype
        "link"
      end
    end
    stat
  end
  module_function :lstat

  private

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa364571(v=vs.85).aspx
  FSCTL_GET_REPARSE_POINT = 0x900a8

  def self.resolve_symlink(handle)
    # must be multiple of 1024, min 10240
    out_buffer = FFI::MemoryPointer.new(API::ReparseDataBuffer.size)
    device_io_control(handle, FSCTL_GET_REPARSE_POINT, nil, out_buffer)

    reparse_data = API::ReparseDataBuffer.new(out_buffer)
    offset = reparse_data[:print_name_offset]
    length = reparse_data[:print_name_length]

    result = reparse_data[:path_buffer].to_a[offset, length].pack('C*')
    result.force_encoding('UTF-16LE').encode(Encoding.default_external)
  end
end
