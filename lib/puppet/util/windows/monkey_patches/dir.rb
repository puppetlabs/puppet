require 'win32/dir/constants'
require 'win32/dir/functions'
require 'win32/dir/structs'

class DirMonkeyPatched
  include ::Dir::Structs
  include ::Dir::Constants
  extend  ::Dir::Functions

  path  = nil
  key   = :PERSONAL
  value = 0x0005
  buf   = 0.chr * 1024
  buf.encode!(Encoding::UTF_16LE)

  if SHGetFolderPathW(0, value, 0, 0, buf) == 0 # Current path
    path = buf.strip
  elsif SHGetFolderPathW(0, value, 0, 1, buf) == 0 # Default path
    path = buf.strip
  else
    FFI::MemoryPointer.new(:long) do |ptr|
      if SHGetFolderLocation(0, value, 0, 0, ptr) == 0
        SHFILEINFO.new do |info|
          flags = SHGFI_DISPLAYNAME | SHGFI_PIDL
          if SHGetFileInfo(ptr.read_long, 0, info, info.size, flags) != 0
            path = info[:szDisplayName].to_s
          end
        end
      end
    end
  end

  if path.nil?
    begin
      Dir.const_set(key, ''.encode(Encoding.default_external))
    rescue Encoding::UndefinedConversionError
      Dir.const_set(key, ''.encode(Encoding::UTF_8))
    end
  end
end
