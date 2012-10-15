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

    # Convert a SID pointer to a string, e.g. "S-1-5-32-544".
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
    # Win32 APIs that expect a PSID, e.g. IsValidSid.
    def string_to_sid_ptr(string, &block)
      sid_buf = 0.chr * 80
      string_addr = [string].pack('p*').unpack('L')[0]

      raise Puppet::Util::Windows::Error.new("Failed to convert string SID: #{string}") unless ConvertStringSidToSid(string_addr, sid_buf)

      sid_ptr = sid_buf.unpack('L')[0]
      begin
        if block_given?
          yield sid_ptr
        else
          true
        end
      ensure
        LocalFree(sid_ptr)
      end
    end
  end
end
