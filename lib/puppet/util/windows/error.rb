require 'puppet/util/windows'

# represents an error resulting from a Win32 error code
class Puppet::Util::Windows::Error < Puppet::Error
  require 'ffi'
  extend FFI::Library

  attr_reader :code

  # NOTE: FFI.errno only works properly when prior Win32 calls have been made
  # through FFI bindings.  Calls made through Win32API do not have their error
  # codes captured by FFI.errno
  def initialize(message, code = FFI.errno, original = nil)
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
    error_string = ''

    # this pointer actually points to a :lpwstr (pointer) since we're letting Windows allocate for us
    FFI::MemoryPointer.new(:pointer, 1) do |buffer_ptr|
      length = FormatMessageW(flags, FFI::Pointer::NULL, code, dwLanguageId,
        buffer_ptr, 0, FFI::Pointer::NULL)

      if length == FFI::WIN32_FALSE
        # can't raise same error type here or potentially recurse infinitely
        raise Puppet::Error.new(_("FormatMessageW could not format code %{code}") % { code: code })
      end

      # returns an FFI::Pointer with autorelease set to false, which is what we want
      buffer_ptr.read_win32_local_pointer do |wide_string_ptr|
        if wide_string_ptr.null?
          raise Puppet::Error.new(_("FormatMessageW failed to allocate buffer for code %{code}") % { code: code })
        end

        error_string = wide_string_ptr.read_wide_string(length)
      end
    end

    error_string
  end

  ERROR_FILE_NOT_FOUND      = 2
  ERROR_ACCESS_DENIED       = 5

  FORMAT_MESSAGE_ALLOCATE_BUFFER   = 0x00000100
  FORMAT_MESSAGE_IGNORE_INSERTS    = 0x00000200
  FORMAT_MESSAGE_FROM_SYSTEM       = 0x00001000
  FORMAT_MESSAGE_ARGUMENT_ARRAY    = 0x00002000
  FORMAT_MESSAGE_MAX_WIDTH_MASK    = 0x000000FF

  ffi_convention :stdcall

  # https://msdn.microsoft.com/en-us/library/windows/desktop/ms679351(v=vs.85).aspx
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
end
