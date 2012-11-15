require 'puppet/util/windows'

module Puppet::Util::Windows
  module Registry
    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa384129(v=vs.85).aspx
    KEY64 = 0x100
    KEY32 = 0x200

    KEY_READ       = 0x20019
    KEY_WRITE      = 0x20006
    KEY_ALL_ACCESS = 0x2003f

    def root(name)
      Win32::Registry.const_get(name)
    rescue NameError
      raise Puppet::Error, "Invalid registry key '#{name}'"
    end

    def open(name, path, mode = KEY_READ | KEY64, &block)
      hkey = root(name)
      begin
        hkey.open(path, mode) do |subkey|
          return yield subkey
        end
      rescue Win32::Registry::Error => error
        raise Puppet::Util::Windows::Error.new("Failed to open registry key '#{hkey.keyname}\\#{path}'", error.code)
      end
    end

    def values(subkey)
      values = {}
      subkey.each_value { |name, type, data| values[name] = data }
      values
    end
  end
end
