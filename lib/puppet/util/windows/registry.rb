require 'puppet/util/windows'

module Puppet::Util::Windows
  module Registry
    require 'ffi'
    extend FFI::Library

    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa384129(v=vs.85).aspx
    KEY64 = 0x100
    KEY32 = 0x200

    KEY_READ       = 0x20019
    KEY_WRITE      = 0x20006
    KEY_ALL_ACCESS = 0x2003f

    def root(name)
      Win32::Registry.const_get(name)
    rescue NameError
      raise Puppet::Error, "Invalid registry key '#{name}'", $!.backtrace
    end

    def open(name, path, mode = KEY_READ | KEY64, &block)
      hkey = root(name)
      begin
        hkey.open(path, mode) do |subkey|
          return yield subkey
        end
      rescue Win32::Registry::Error => error
        raise Puppet::Util::Windows::Error.new("Failed to open registry key '#{hkey.keyname}\\#{path}'", error.code, error)
      end
    end

    def values(subkey)
      values = {}
      orig_enc = Encoding.default_internal

      begin
        Encoding.default_internal = Encoding::UTF_8
        subkey.each_value do |name, type, data|
          values[name] = data
        end
      rescue Encoding::UndefinedConversionError, Encoding::CompatibilityError => error
        raise Puppet::Error.new("Failed to get registry key values for '#{subkey.name}'.\n  #{error.to_s}")
      ensure
        Encoding.default_internal = orig_enc
      end

      values
    end

    ffi_convention :stdcall

    # http://msdn.microsoft.com/en-us/library/windows/desktop/dd318070(v=vs.85).aspx
    # UINT GetACP(void);
    ffi_lib :kernel32
    attach_function_private :GetACP, [], :uint32
  end
end
