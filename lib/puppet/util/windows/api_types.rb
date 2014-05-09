require 'ffi'

module Puppet::Util::Windows::APITypes
  module ::FFI::Library
    # Wrapper method for attach_function + private
    def attach_function_private(*args)
      attach_function(*args)
      private args[0]
    end
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
