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
      subkey.each_value do |name, type, data|
        case type
        when Win32::Registry::REG_MULTI_SZ
          data.each { |str| force_encoding(str) }
        when Win32::Registry::REG_SZ, Win32::Registry::REG_EXPAND_SZ
          force_encoding(data)
        end
        values[name] = data
      end
      values
    end

    if defined?(Encoding)
      def force_encoding(str)
        if @encoding.nil?
          # See https://bugs.ruby-lang.org/issues/8943
          # Ruby uses ANSI versions of Win32 APIs to read values from the
          # registry. The encoding of these strings depends on the active
          # code page. However, ruby incorrectly sets the string
          # encoding to US-ASCII. So we must force the encoding to the
          # correct value.
          begin
            cp = GetACP()
            @encoding = Encoding.const_get("CP#{cp}")
          rescue
            @encoding = Encoding.default_external
          end
        end

        str.force_encoding(@encoding)
      end
    else
      def force_encoding(str, enc)
      end
    end
    private :force_encoding


    ffi_convention :stdcall

    # http://msdn.microsoft.com/en-us/library/windows/desktop/dd318070(v=vs.85).aspx
    # UINT GetACP(void);
    ffi_lib :kernel32
    attach_function_private :GetACP, [], :uint32
  end
end
