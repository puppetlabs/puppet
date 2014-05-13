require 'ffi'
require 'puppet/util/windows/string'

module Puppet::Util::Windows::APITypes
  module ::FFI::Library
    # Wrapper method for attach_function + private
    def attach_function_private(*args)
      attach_function(*args)
      private args[0]
    end
  end

  class ::FFI::MemoryPointer
    def self.from_string_to_wide_string(str)
      str = Puppet::Util::Windows::String.wide_string(str)
      ptr = FFI::MemoryPointer.new(:byte, str.bytesize)
      # uchar here is synonymous with byte
      ptr.put_array_of_uchar(0, str.bytes.to_a)

      ptr
    end

    def read_bool
      # BOOL is always a 32-bit integer in Win32
      # some Win32 APIs return 1 for true, while others are non-0
      read_int32 != 0
    end

    alias_method :read_dword, :read_uint32

    def read_handle
      type_size == 4 ? read_uint32 : read_uint64
    end

    def read_wide_string(char_length)
      # char_length is number of wide chars (typically excluding NULLs), *not* bytes
      str = get_bytes(0, char_length * 2).force_encoding('UTF-16LE')
      str.encode(Encoding.default_external)
    end

    alias_method :write_dword, :write_uint32
  end

  # FFI Types
  # https://github.com/ffi/ffi/wiki/Types

  # Windows - Common Data Types
  # http://msdn.microsoft.com/en-us/library/cc230309.aspx

  # Windows Data Types
  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa383751(v=vs.85).aspx

  FFI.typedef :uint16, :word
  FFI.typedef :uint32, :dword
  # uintptr_t is defined in an FFI conf as platform specific, either
  # ulong_long on x64 or just ulong on x86
  FFI.typedef :uintptr_t, :handle

  # buffer_inout is similar to pointer (platform specific), but optimized for buffers
  FFI.typedef :buffer_inout, :lpwstr
  # buffer_in is similar to pointer (platform specific), but optimized for CONST read only buffers
  FFI.typedef :buffer_in, :lpcwstr

  # string is also similar to pointer, but should be used for const char *
  # NOTE that this is not wide, useful only for A suffixed functions
  FFI.typedef :string, :lpcstr

  # pointer in FFI is platform specific
  # NOTE: for API calls with reserved lpvoid parameters, pass a FFI::Pointer::NULL
  FFI.typedef :pointer, :lpvoid
  FFI.typedef :pointer, :lpword
  FFI.typedef :pointer, :lpdword
  FFI.typedef :pointer, :pdword
  FFI.typedef :pointer, :phandle
  FFI.typedef :pointer, :ulong_ptr
  FFI.typedef :pointer, :pbool

  # any time LONG / ULONG is in a win32 API definition DO NOT USE platform specific width
  # which is what FFI uses by default
  # instead create new aliases for these very special cases
  # NOTE: not a good idea to redefine FFI :ulong since other typedefs may rely on it
  FFI.typedef :uint32, :win32_ulong
  FFI.typedef :int32, :win32_long

  # NOTE: FFI already defines ushort as a 16-bit unsigned like this:
  # FFI.typedef :uint16, :ushort

  # 8 bits per byte
  FFI.typedef :uchar, :byte
end
