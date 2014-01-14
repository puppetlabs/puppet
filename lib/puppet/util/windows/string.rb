require 'puppet/util/windows'

module Puppet::Util::Windows::String
  require 'ffi'

  def wide_string(str)
    wstr = str.encode('UTF-16LE')

    ptr = FFI::MemoryPointer.new(:uint16, wstr.length + 1)
    ptr.put_string(0, wstr)
    ptr.put_uint8(ptr.size - 1, 0)
    ptr.put_uint8(ptr.size - 2, 0)

    ffi_str = ptr.get_bytes(0, ptr.size)
    ffi_str.force_encoding('UTF-16LE')

    ffi_str.strip
  end
  module_function :wide_string
end
