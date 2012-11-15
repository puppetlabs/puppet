require 'puppet/util/windows'

module Puppet::Util::Windows
  module SID
    require 'windows/security'
    include ::Windows::Security

    require 'windows/memory'
    include ::Windows::Memory

    require 'windows/msvcrt/string'
    include ::Windows::MSVCRT::String

    # missing from Windows::Error
    ERROR_NONE_MAPPED           = 1332
    ERROR_INVALID_SID_STRUCTURE = 1337

    # Convert an account name, e.g. 'Administrators' into a SID string,
    # e.g. 'S-1-5-32-544'. The name can be specified as 'Administrators',
    # 'BUILTIN\Administrators', or 'S-1-5-32-544', and will return the
    # SID. Returns nil if the account doesn't exist.
    def name_to_sid(name)
      # Apparently, we accept a symbol..
      name = name.to_s if name

      # if it's in SID string form, return it, otherwise, lookup sid
      is_sid = Win32::Security::SID.string_to_sid(name) rescue nil

      is_sid ? name : Win32::Security::SID.new(name).to_s
    rescue
      nil
    end

    # Convert a SID string, e.g. "S-1-5-32-544" to a name,
    # e.g. 'BUILTIN\Administrators'. Returns nil if an account
    # for that SID does not exist.
    def sid_to_name(value)
      sid = Win32::Security::SID.new(Win32::Security::SID.string_to_sid(value))

      if sid.domain and sid.domain.length > 0
        "#{sid.domain}\\#{sid.account}"
      else
        sid.account
      end
    rescue
      nil
    end

    # Convert a SID pointer to a SID string, e.g. "S-1-5-32-544".
    def sid_ptr_to_string(psid)
      sid_buf = 0.chr * 256
      str_ptr = 0.chr * 4

      raise Puppet::Util::Windows::Error.new("Invalid SID") unless IsValidSid(psid)

      raise Puppet::Util::Windows::Error.new("Failed to convert binary SID") unless ConvertSidToStringSid(psid, str_ptr)

      begin
        strncpy(sid_buf, str_ptr.unpack('L')[0], sid_buf.size - 1)
        sid_buf[sid_buf.size - 1] = 0.chr
        return sid_buf.strip
      ensure
        LocalFree(str_ptr.unpack('L')[0])
      end
    end

    # Convert a SID string, e.g. "S-1-5-32-544" to a pointer (containing the
    # address of the binary SID structure). The returned value can be used in
    # Win32 APIs that expect a PSID, e.g. IsValidSid. The account for this
    # SID may or may not exist.
    def string_to_sid_ptr(string, &block)
      sid_buf = 0.chr * 80
      string_addr = [string].pack('p*').unpack('L')[0]

      raise Puppet::Util::Windows::Error.new("Failed to convert string SID: #{string}") unless ConvertStringSidToSid(string_addr, sid_buf)

      sid_ptr = sid_buf.unpack('L')[0]
      begin
        yield sid_ptr
      ensure
        LocalFree(sid_ptr)
      end
    end

    # Return true if the string is a valid SID, e.g. "S-1-5-32-544", false otherwise.
    def valid_sid?(string)
      string_to_sid_ptr(string) { |ptr| true }
    rescue Puppet::Util::Windows::Error => e
      if e.code == ERROR_INVALID_SID_STRUCTURE
        false
      else
        raise
      end
    end
  end
end
