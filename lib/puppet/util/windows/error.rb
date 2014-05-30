require 'puppet/util/windows'

# represents an error resulting from a Win32 error code
class Puppet::Util::Windows::Error < Puppet::Error
  require 'ffi'
  extend FFI::Library

  attr_reader :code

  def initialize(message, code = @@GetLastError.call(), original = nil)
    super(message + ":  #{self.class.format_error_code(code)}", original)

    @code = code
  end

  # Helper method that wraps FormatMessage that returns a human readable string.
  def self.format_error_code(code)
    # specifying 0 will look for LANGID in the following order
    # 1.Language neutral
    # 2.Thread LANGID, based on the thread's locale value
    # 3.User default LANGID, based on the user's default locale value
    # 4.System default LANGID, based on the system default locale value
    # 5.US English
    dwLanguageId = 0
    flags = FORMAT_MESSAGE_ALLOCATE_BUFFER |
            FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_ARGUMENT_ARRAY |
            FORMAT_MESSAGE_IGNORE_INSERTS |
            FORMAT_MESSAGE_MAX_WIDTH_MASK
    # this pointer actually points to a :lpwstr (pointer) since we're letting Windows allocate for us
    buffer_ptr = FFI::MemoryPointer.new(:pointer, 1)

    begin
      length = FormatMessageW(flags, FFI::Pointer::NULL, code, dwLanguageId,
        buffer_ptr, 0, FFI::Pointer::NULL)

      if length == FFI::WIN32_FALSE
        # can't raise same error type here or potentially recurse infinitely
        raise Puppet::Error.new("FormatMessageW could not format code #{code}")
      end

      # returns an FFI::Pointer with autorelease set to false, which is what we want
      wide_string_ptr = buffer_ptr.read_pointer

      if wide_string_ptr.null?
        raise Puppet::Error.new("FormatMessageW failed to allocate buffer for code #{code}")
      end

      return wide_string_ptr.read_wide_string(length)
    ensure
      if ! wide_string_ptr.nil? && ! wide_string_ptr.null?
        if LocalFree(wide_string_ptr.address) != FFI::Pointer::NULL_HANDLE
          Puppet.debug "LocalFree memory leak"
        end
      end
    end
  end

  FORMAT_MESSAGE_ALLOCATE_BUFFER   = 0x00000100
  FORMAT_MESSAGE_IGNORE_INSERTS    = 0x00000200
  FORMAT_MESSAGE_FROM_SYSTEM       = 0x00001000
  FORMAT_MESSAGE_ARGUMENT_ARRAY    = 0x00002000
  FORMAT_MESSAGE_MAX_WIDTH_MASK    = 0x000000FF

  ffi_convention :stdcall

  # NOTE: It seems like FFI.errno is already implemented as GetLastError... or is it?
  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms679360(v=vs.85).aspx
  # DWORD WINAPI GetLastError(void);
  # HACK: unfortunately using FFI.errno or attach_function to hook GetLastError in
  # FFI like the following will not work.  Something internal to FFI appears to
  # be stomping out the value of GetLastError when calling via FFI.
  # attach_function_private :GetLastError, [], :dword
  require 'Win32API'
  @@GetLastError = Win32API.new('kernel32', 'GetLastError', [], 'L')

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms679351(v=vs.85).aspx
  # DWORD WINAPI FormatMessage(
  #   _In_      DWORD dwFlags,
  #   _In_opt_  LPCVOID lpSource,
  #   _In_      DWORD dwMessageId,
  #   _In_      DWORD dwLanguageId,
  #   _Out_     LPTSTR lpBuffer,
  #   _In_      DWORD nSize,
  #   _In_opt_  va_list *Arguments
  # );
  # NOTE: since we're not preallocating the buffer, use a :pointer for lpBuffer
  ffi_lib :kernel32
  attach_function_private :FormatMessageW,
    [:dword, :lpcvoid, :dword, :dword, :pointer, :dword, :pointer], :dword

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa366730(v=vs.85).aspx
  # HLOCAL WINAPI LocalFree(
  #   _In_  HLOCAL hMem
  # );
  ffi_lib :kernel32
  attach_function_private :LocalFree, [:handle], :handle
end
