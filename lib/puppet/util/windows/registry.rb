# frozen_string_literal: true

require_relative '../../../puppet/util/windows'

module Puppet::Util::Windows
  module Registry
    require 'ffi'
    extend FFI::Library

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384129(v=vs.85).aspx
    KEY64 = 0x100
    KEY32 = 0x200

    KEY_READ       = 0x20019
    KEY_WRITE      = 0x20006
    KEY_ALL_ACCESS = 0x2003f

    ERROR_NO_MORE_ITEMS = 259

    WCHAR_SIZE = FFI.type_size(:wchar)

    def root(name)
      Win32::Registry.const_get(name)
    rescue NameError
      raise Puppet::Error, _("Invalid registry key '%{name}'") % { name: name }, $!.backtrace
    end

    def open(name, path, mode = KEY_READ | KEY64, &block)
      hkey = root(name)
      begin
        hkey.open(path, mode) do |subkey|
          return yield subkey
        end
      rescue Win32::Registry::Error => error
        raise Puppet::Util::Windows::Error.new(_("Failed to open registry key '%{key}\\%{path}'") % { key: hkey.keyname, path: path }, error.code, error)
      end
    end

    def keys(key)
      keys = {}
      each_key(key) { |subkey, filetime| keys[subkey] = filetime }
      keys
    end

    # subkey is String which contains name of subkey.
    # wtime is last write time as FILETIME (64-bit integer). (see Registry.wtime2time)
    def each_key(key, &block)
      index = 0
      subkey = nil

      subkey_max_len, _ = reg_query_info_key_max_lengths(key)

      loop do
        subkey, filetime = reg_enum_key(key, index, subkey_max_len)
        yield subkey, filetime unless subkey.nil?
        index += 1
        break if subkey.nil?
      end

      index
    end

    def delete_key(key, subkey_name, mode = KEY64)
      reg_delete_key_ex(key, subkey_name, mode)
    end

    def values(key)
      vals = {}
      each_value(key) { |subkey, _type, data| vals[subkey] = data }
      vals
    end

    # Retrieve a set of values from a registry key given their names
    # Value names listed but not found in the registry will not be added to the
    # resultant Hashtable
    #
    # @param key [RegistryKey] An open handle to a Registry Key
    # @param names [String[]] An array of names of registry values to return if they exist
    # @return [Hashtable<String, Object>] A hashtable of all of the found values in the registry key
    def values_by_name(key, names)
      vals = {}
      names.each do |name|
        FFI::Pointer.from_string_to_wide_string(name) do |subkeyname_ptr|
          begin
            _, vals[name] = read(key, subkeyname_ptr)
          rescue Puppet::Util::Windows::Error => e
            # ignore missing names, but raise other errors
            raise e unless e.code == Puppet::Util::Windows::Error::ERROR_FILE_NOT_FOUND
          end
        end
      end
      vals
    end

    def each_value(key, &block)
      index = 0
      subkey = nil

      _, value_max_len = reg_query_info_key_max_lengths(key)

      loop do
        subkey, type, data = reg_enum_value(key, index, value_max_len)
        yield subkey, type, data unless subkey.nil?
        index += 1
        break if subkey.nil?
      end

      index
    end

    def delete_value(key, subkey_name)
      reg_delete_value(key, subkey_name)
    end

    private

    # max number of wide characters including NULL terminator
    MAX_KEY_CHAR_LENGTH = 255 + 1

    def reg_enum_key(key, index, max_key_char_length = MAX_KEY_CHAR_LENGTH)
      subkey = nil
      filetime = nil

      FFI::MemoryPointer.new(:dword) do |subkey_length_ptr|
        FFI::MemoryPointer.new(FFI::WIN32::FILETIME.size) do |filetime_ptr|
          FFI::MemoryPointer.new(:wchar, max_key_char_length) do |subkey_ptr|
            subkey_length_ptr.write_dword(max_key_char_length)

            # RegEnumKeyEx cannot be called twice to properly size the buffer
            result = RegEnumKeyExW(key.hkey, index,
                                   subkey_ptr, subkey_length_ptr,
                                   FFI::Pointer::NULL, FFI::Pointer::NULL,
                                   FFI::Pointer::NULL, filetime_ptr)

            break if result == ERROR_NO_MORE_ITEMS

            if result != FFI::ERROR_SUCCESS
              msg = _("Failed to enumerate %{key} registry keys at index %{index}") % { key: key.keyname, index: index }
              raise Puppet::Util::Windows::Error.new(msg, result)
            end

            filetime = FFI::WIN32::FILETIME.new(filetime_ptr)
            subkey_length = subkey_length_ptr.read_dword
            subkey = subkey_ptr.read_wide_string(subkey_length)
          end
        end
      end

      [subkey, filetime]
    end

    # max number of wide characters including NULL terminator
    MAX_VALUE_CHAR_LENGTH = 16_383 + 1

    def reg_enum_value(key, index, max_value_length = MAX_VALUE_CHAR_LENGTH)
      subkey = nil
      type = nil
      data = nil

      FFI::MemoryPointer.new(:dword) do |subkey_length_ptr|
        FFI::MemoryPointer.new(:wchar, max_value_length) do |subkey_ptr|
          # RegEnumValueW cannot be called twice to properly size the buffer
          subkey_length_ptr.write_dword(max_value_length)

          result = RegEnumValueW(key.hkey, index,
                                 subkey_ptr, subkey_length_ptr,
                                 FFI::Pointer::NULL, FFI::Pointer::NULL,
                                 FFI::Pointer::NULL, FFI::Pointer::NULL)

          break if result == ERROR_NO_MORE_ITEMS

          if result != FFI::ERROR_SUCCESS
            msg = _("Failed to enumerate %{key} registry values at index %{index}") % { key: key.keyname, index: index }
            raise Puppet::Util::Windows::Error.new(msg, result)
          end

          subkey_length = subkey_length_ptr.read_dword
          subkey = subkey_ptr.read_wide_string(subkey_length)

          type, data = read(key, subkey_ptr)
        end
      end

      [subkey, type, data]
    end

    def reg_query_info_key_max_lengths(key)
      result = nil

      FFI::MemoryPointer.new(:dword) do |max_subkey_name_length_ptr|
        FFI::MemoryPointer.new(:dword) do |max_value_name_length_ptr|
          status = RegQueryInfoKeyW(key.hkey,
                                    FFI::MemoryPointer::NULL, FFI::MemoryPointer::NULL,
                                    FFI::MemoryPointer::NULL, FFI::MemoryPointer::NULL,
                                    max_subkey_name_length_ptr, FFI::MemoryPointer::NULL,
                                    FFI::MemoryPointer::NULL, max_value_name_length_ptr,
                                    FFI::MemoryPointer::NULL, FFI::MemoryPointer::NULL,
                                    FFI::MemoryPointer::NULL)

          if status != FFI::ERROR_SUCCESS
            msg = _("Failed to query registry %{key} for sizes") % { key: key.keyname }
            raise Puppet::Util::Windows::Error.new(msg, status)
          end

          result = [
            # Unicode characters *not* including trailing NULL
            max_subkey_name_length_ptr.read_dword + 1,
            max_value_name_length_ptr.read_dword + 1,
          ]
        end
      end

      result
    end

    # Read a registry value named name and return array of
    # [ type, data ].
    # When name is nil, the `default' value is read.
    # type is value type. (see Win32::Registry::Constants module)
    # data is value data, its class is:
    # :REG_SZ, REG_EXPAND_SZ
    #    String
    # :REG_MULTI_SZ
    #    Array of String
    # :REG_DWORD, REG_DWORD_BIG_ENDIAN, REG_QWORD
    #    Integer
    # :REG_BINARY
    #    String (contains binary data)
    #
    # When rtype is specified, the value type must be included by
    # rtype array, or TypeError is raised.
    def read(key, name_ptr, *rtype)
      result = nil

      query_value_ex(key, name_ptr) do |type, data_ptr, byte_length|
        unless rtype.empty? or rtype.include?(type)
          raise TypeError, _("Type mismatch (expect %{rtype} but %{type} present)") % { rtype: rtype.inspect, type: type }
        end

        string_length = 0
        # buffer is raw bytes, *not* chars - less a NULL terminator
        string_length = (byte_length / WCHAR_SIZE) - 1 if byte_length > 0

        begin
          result = case type
                   when Win32::Registry::REG_SZ, Win32::Registry::REG_EXPAND_SZ
                     [type, data_ptr.read_wide_string(string_length, Encoding::UTF_8, true)]
                   when Win32::Registry::REG_MULTI_SZ
                     [type, data_ptr.read_wide_string(string_length).split(/\0/)]
                   when Win32::Registry::REG_BINARY
                     [type, data_ptr.read_bytes(byte_length)]
                   when Win32::Registry::REG_DWORD
                     [type, data_ptr.read_dword]
                   when Win32::Registry::REG_DWORD_BIG_ENDIAN
                     [type, data_ptr.order(:big).read_dword]
                   when Win32::Registry::REG_QWORD
                     [type, data_ptr.read_qword]
                   else
                     raise TypeError, _("Type %{type} is not supported.") % { type: type }
                   end
        rescue IndexError => ex
          raise if (ex.message !~ /^Memory access .* is out of bounds$/i)

          parent_key_name = key.parent ? "#{key.parent.keyname}\\" : ""
          Puppet.warning _("A value in the registry key %{parent_key_name}%{key} is corrupt or invalid") % { parent_key_name: parent_key_name, key: key.keyname }
        end
      end

      result
    end

    def query_value_ex(key, name_ptr, &block)
      FFI::MemoryPointer.new(:dword) do |type_ptr|
        FFI::MemoryPointer.new(:dword) do |length_ptr|
          result = RegQueryValueExW(key.hkey, name_ptr,
                                    FFI::Pointer::NULL, type_ptr,
                                    FFI::Pointer::NULL, length_ptr)

          # The call to RegQueryValueExW below is potentially unsafe:
          # https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-regqueryvalueexw
          #
          #   "If the data has the REG_SZ, REG_MULTI_SZ or REG_EXPAND_SZ type,
          #   the string may not have been stored with the proper terminating
          #   null characters. Therefore, even if the function returns
          #   ERROR_SUCCESS, the application should ensure that the string is
          #   properly terminated before using it; otherwise, it may overwrite a
          #   buffer. (Note that REG_MULTI_SZ strings should have two
          #   terminating null characters.)"
          #
          # Since we don't know if the values will be properly null terminated,
          # extend the buffer to guarantee we can append one or two wide null
          # characters, without overwriting any data.
          base_bytes_len = length_ptr.read_dword
          pad_bytes_len = case type_ptr.read_dword
                          when Win32::Registry::REG_SZ, Win32::Registry::REG_EXPAND_SZ
                            WCHAR_SIZE
                          when Win32::Registry::REG_MULTI_SZ
                            WCHAR_SIZE * 2
                          else
                            0
                          end

          FFI::MemoryPointer.new(:byte, base_bytes_len + pad_bytes_len) do |buffer_ptr|
            result = RegQueryValueExW(key.hkey, name_ptr,
                                      FFI::Pointer::NULL, type_ptr,
                                      buffer_ptr, length_ptr)

            # Ensure buffer is null terminated with 1 or 2 wchar nulls, depending on the type
            if result == FFI::ERROR_SUCCESS
              case type_ptr.read_dword
              when Win32::Registry::REG_SZ, Win32::Registry::REG_EXPAND_SZ
                buffer_ptr.put_uint16(base_bytes_len, 0)
              when Win32::Registry::REG_MULTI_SZ
                buffer_ptr.put_uint16(base_bytes_len, 0)
                buffer_ptr.put_uint16(base_bytes_len + WCHAR_SIZE, 0)
              end
            else
              # buffer is raw bytes, *not* chars - less a NULL terminator
              name_length = (name_ptr.size / WCHAR_SIZE) - 1 if name_ptr.size > 0
              msg = _("Failed to read registry value %{value} at %{key}") % { value: name_ptr.read_wide_string(name_length), key: key.keyname }
              raise Puppet::Util::Windows::Error.new(msg, result)
            end

            # allows caller to use FFI MemoryPointer helpers to read / shape
            yield [type_ptr.read_dword, buffer_ptr, length_ptr.read_dword]
          end
        end
      end
    end

    def reg_delete_value(key, name)
      result = 0

      FFI::Pointer.from_string_to_wide_string(name) do |name_ptr|
        result = RegDeleteValueW(key.hkey, name_ptr)

        if result != FFI::ERROR_SUCCESS
          msg = _("Failed to delete registry value %{name} at %{key}") % { name: name, key: key.keyname }
          raise Puppet::Util::Windows::Error.new(msg, result)
        end
      end

      result
    end

    def reg_delete_key_ex(key, name, regsam = KEY64)
      result = 0

      FFI::Pointer.from_string_to_wide_string(name) do |name_ptr|
        result = RegDeleteKeyExW(key.hkey, name_ptr, regsam, 0)

        if result != FFI::ERROR_SUCCESS
          msg = _("Failed to delete registry key %{name} at %{key}") % { name: name, key: key.keyname }
          raise Puppet::Util::Windows::Error.new(msg, result)
        end
      end

      result
    end

    ffi_convention :stdcall

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724862(v=vs.85).aspx
    # LONG WINAPI RegEnumKeyEx(
    #   _In_         HKEY hKey,
    #   _In_         DWORD dwIndex,
    #   _Out_        LPTSTR lpName,
    #   _Inout_      LPDWORD lpcName,
    #   _Reserved_   LPDWORD lpReserved,
    #   _Inout_      LPTSTR lpClass,
    #   _Inout_opt_  LPDWORD lpcClass,
    #   _Out_opt_    PFILETIME lpftLastWriteTime
    # );
    ffi_lib :advapi32
    attach_function_private :RegEnumKeyExW,
                            [:handle, :dword, :lpwstr, :lpdword, :lpdword, :lpwstr, :lpdword, :pointer], :win32_long

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724865(v=vs.85).aspx
    # LONG WINAPI RegEnumValue(
    #   _In_         HKEY hKey,
    #   _In_         DWORD dwIndex,
    #   _Out_        LPTSTR lpValueName,
    #   _Inout_      LPDWORD lpcchValueName,
    #   _Reserved_   LPDWORD lpReserved,
    #   _Out_opt_    LPDWORD lpType,
    #   _Out_opt_    LPBYTE lpData,
    #   _Inout_opt_  LPDWORD lpcbData
    # );
    ffi_lib :advapi32
    attach_function_private :RegEnumValueW,
                            [:handle, :dword, :lpwstr, :lpdword, :lpdword, :lpdword, :lpbyte, :lpdword], :win32_long

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724911(v=vs.85).aspx
    # LONG WINAPI RegQueryValueExW(
    #   _In_         HKEY hKey,
    #   _In_opt_     LPCTSTR lpValueName,
    #   _Reserved_   LPDWORD lpReserved,
    #   _Out_opt_    LPDWORD lpType,
    #   _Out_opt_    LPBYTE lpData,
    #   _Inout_opt_  LPDWORD lpcbData
    # );
    ffi_lib :advapi32
    attach_function_private :RegQueryValueExW,
                            [:handle, :lpcwstr, :lpdword, :lpdword, :lpbyte, :lpdword], :win32_long

    # LONG WINAPI RegDeleteValue(
    #   _In_      HKEY hKey,
    #   _In_opt_  LPCTSTR lpValueName
    # );
    ffi_lib :advapi32
    attach_function_private :RegDeleteValueW,
                            [:handle, :lpcwstr], :win32_long

    # LONG WINAPI RegDeleteKeyEx(
    #   _In_        HKEY hKey,
    #   _In_        LPCTSTR lpSubKey,
    #   _In_        REGSAM samDesired,
    #   _Reserved_  DWORD Reserved
    # );
    ffi_lib :advapi32
    attach_function_private :RegDeleteKeyExW,
                            [:handle, :lpcwstr, :win32_ulong, :dword], :win32_long

    # https://msdn.microsoft.com/en-us/library/windows/desktop/ms724902(v=vs.85).aspx
    # LONG WINAPI RegQueryInfoKey(
    #   _In_         HKEY hKey,
    #   _Out_opt_    LPTSTR lpClass,
    #   _Inout_opt_  LPDWORD lpcClass,
    #   _Reserved_   LPDWORD lpReserved,
    #   _Out_opt_    LPDWORD lpcSubKeys,
    #   _Out_opt_    LPDWORD lpcMaxSubKeyLen,
    #   _Out_opt_    LPDWORD lpcMaxClassLen,
    #   _Out_opt_    LPDWORD lpcValues,
    #   _Out_opt_    LPDWORD lpcMaxValueNameLen,
    #   _Out_opt_    LPDWORD lpcMaxValueLen,
    #   _Out_opt_    LPDWORD lpcbSecurityDescriptor,
    #   _Out_opt_    PFILETIME lpftLastWriteTime
    # );
    ffi_lib :advapi32
    attach_function_private :RegQueryInfoKeyW,
                            [:handle, :lpwstr, :lpdword, :lpdword, :lpdword,
                             :lpdword, :lpdword, :lpdword, :lpdword, :lpdword,
                             :lpdword, :pointer], :win32_long
  end
end
