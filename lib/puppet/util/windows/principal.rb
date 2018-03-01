require 'puppet/util/windows'

module Puppet::Util::Windows::SID
  class Principal
    extend FFI::Library
    attr_reader :account, :sid_bytes, :sid, :domain, :domain_account, :account_type

    def initialize(account, sid_bytes, sid, domain, account_type)
      # This is only ever called from lookup_account_sid which has already
      # removed the potential for passing in an account like host\user
      @account = account
      @sid_bytes = sid_bytes
      @sid = sid
      @domain = domain
      @account_type = account_type
      # When domain is available and it is a Domain principal, use domain only
      #   otherwise if domain is available then combine it with parsed account
      #   otherwise when the domain is not available, use the account value directly
      # WinNT naming standard https://msdn.microsoft.com/en-us/library/windows/desktop/aa746534(v=vs.85).aspx
      if (domain && !domain.empty? && @account_type == :SidTypeDomain)
        @domain_account = @domain
      elsif (domain && !domain.empty?)
        @domain_account =  "#{domain}\\#{@account}"
      else
        @domain_account = account
      end
    end

    # added for backward compatibility
    def ==(compare)
      compare.is_a?(Puppet::Util::Windows::SID::Principal) &&
        @sid_bytes == compare.sid_bytes
    end

    # returns authority qualified account name
    # prefer to compare Principal instances with == operator or by #sid
    def to_s
      @domain_account
    end

    # = 8 + max sub identifiers (15) * 4
    MAXIMUM_SID_BYTE_LENGTH = 68

    ERROR_INSUFFICIENT_BUFFER = 122

    def self.lookup_account_name(system_name = nil, account_name)
      system_name_ptr = FFI::Pointer::NULL
      begin
        if system_name
          system_name_wide = Puppet::Util::Windows::String.wide_string(system_name)
          # uchar here is synonymous with byte
          system_name_ptr = FFI::MemoryPointer.new(:byte, system_name_wide.bytesize)
          system_name_ptr.put_array_of_uchar(0, system_name_wide.bytes.to_a)
        end

        FFI::MemoryPointer.from_string_to_wide_string(account_name) do |account_name_ptr|
          FFI::MemoryPointer.new(:byte, MAXIMUM_SID_BYTE_LENGTH) do |sid_ptr|
            FFI::MemoryPointer.new(:dword, 1) do |sid_length_ptr|
              FFI::MemoryPointer.new(:dword, 1) do |domain_length_ptr|
                FFI::MemoryPointer.new(:uint32, 1) do |name_use_enum_ptr|

                sid_length_ptr.write_dword(MAXIMUM_SID_BYTE_LENGTH)
                success = LookupAccountNameW(system_name_ptr, account_name_ptr, sid_ptr, sid_length_ptr,
                  FFI::Pointer::NULL, domain_length_ptr, name_use_enum_ptr)
                last_error = FFI.errno

                if (success == FFI::WIN32_FALSE && last_error != ERROR_INSUFFICIENT_BUFFER)
                  raise Puppet::Util::Windows::Error.new(_('Failed to call LookupAccountNameW with account: %{account_name}') % { account_name: account_name}, last_error)
                end

                FFI::MemoryPointer.new(:lpwstr, domain_length_ptr.read_dword) do |domain_ptr|
                  if LookupAccountNameW(system_name_ptr, account_name_ptr,
                      sid_ptr, sid_length_ptr,
                      domain_ptr, domain_length_ptr, name_use_enum_ptr) == FFI::WIN32_FALSE
                  raise Puppet::Util::Windows::Error.new(_('Failed to call LookupAccountNameW with account: %{account_name}') % { account_name: account_name} )
                  end

                  # with a SID returned, loop back through lookup_account_sid to retrieve official name
                  # necessary when accounts like . or '' are passed in
                  return lookup_account_sid(
                    system_name,
                    sid_ptr.read_bytes(sid_length_ptr.read_dword).unpack('C*'))
                  end
                end
              end
            end
          end
        end
      ensure
        system_name_ptr.free if system_name_ptr != FFI::Pointer::NULL
      end
    end

    def self.lookup_account_sid(system_name = nil, sid_bytes)
      system_name_ptr = FFI::Pointer::NULL
      if (sid_bytes.nil? || (!sid_bytes.is_a? Array) || (sid_bytes.length == 0))
        #TRANSLATORS `lookup_account_sid` is a variable name and should not be translated
        raise Puppet::Util::Windows::Error.new(_('Byte array for lookup_account_sid must not be nil and must be at least 1 byte long'))
      end

      begin
        if system_name
          system_name_wide = Puppet::Util::Windows::String.wide_string(system_name)
          # uchar here is synonymous with byte
          system_name_ptr = FFI::MemoryPointer.new(:byte, system_name_wide.bytesize)
          system_name_ptr.put_array_of_uchar(0, system_name_wide.bytes.to_a)
        end

        FFI::MemoryPointer.new(:byte, sid_bytes.length) do |sid_ptr|
          FFI::MemoryPointer.new(:dword, 1) do |name_length_ptr|
            FFI::MemoryPointer.new(:dword, 1) do |domain_length_ptr|
              FFI::MemoryPointer.new(:uint32, 1) do |name_use_enum_ptr|

                sid_ptr.write_array_of_uchar(sid_bytes)
                success = LookupAccountSidW(system_name_ptr, sid_ptr, FFI::Pointer::NULL, name_length_ptr,
                  FFI::Pointer::NULL, domain_length_ptr, name_use_enum_ptr)
                last_error = FFI.errno

                if (success == FFI::WIN32_FALSE && last_error != ERROR_INSUFFICIENT_BUFFER)
                  raise Puppet::Util::Windows::Error.new(_('Failed to call LookupAccountSidW with bytes: %{sid_bytes}') % { sid_bytes: sid_bytes}, last_error)
                end

                FFI::MemoryPointer.new(:lpwstr, name_length_ptr.read_dword) do |name_ptr|
                  FFI::MemoryPointer.new(:lpwstr, domain_length_ptr.read_dword) do |domain_ptr|
                    if LookupAccountSidW(system_name_ptr, sid_ptr, name_ptr, name_length_ptr,
                        domain_ptr, domain_length_ptr, name_use_enum_ptr) == FFI::WIN32_FALSE
                     raise Puppet::Util::Windows::Error.new(_('Failed to call LookupAccountSidW with bytes: %{sid_bytes}') % { sid_bytes: sid_bytes} )
                    end

                    return new(
                      name_ptr.read_wide_string(name_length_ptr.read_dword),
                      sid_bytes,
                      Puppet::Util::Windows::SID.sid_ptr_to_string(sid_ptr),
                      domain_ptr.read_wide_string(domain_length_ptr.read_dword),
                      SID_NAME_USE[name_use_enum_ptr.read_uint32])
                  end
                end
              end
            end
          end
        end
      ensure
        system_name_ptr.free if system_name_ptr != FFI::Pointer::NULL
      end
    end

    ffi_convention :stdcall

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379601(v=vs.85).aspx
    SID_NAME_USE = enum(
      :SidTypeUser, 1,
      :SidTypeGroup, 2,
      :SidTypeDomain, 3,
      :SidTypeAlias, 4,
      :SidTypeWellKnownGroup, 5,
      :SidTypeDeletedAccount, 6,
      :SidTypeInvalid, 7,
      :SidTypeUnknown, 8,
      :SidTypeComputer, 9,
      :SidTypeLabel, 10
    )

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379159(v=vs.85).aspx
    # BOOL WINAPI LookupAccountName(
    #   _In_opt_  LPCTSTR       lpSystemName,
    #   _In_      LPCTSTR       lpAccountName,
    #   _Out_opt_ PSID          Sid,
    #   _Inout_   LPDWORD       cbSid,
    #   _Out_opt_ LPTSTR        ReferencedDomainName,
    #   _Inout_   LPDWORD       cchReferencedDomainName,
    #   _Out_     PSID_NAME_USE peUse
    # );
    ffi_lib :advapi32
    attach_function_private :LookupAccountNameW,
      [:lpcwstr, :lpcwstr, :pointer, :lpdword, :lpwstr, :lpdword, :pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379166(v=vs.85).aspx
    # BOOL WINAPI LookupAccountSid(
    #   _In_opt_  LPCTSTR       lpSystemName,
    #   _In_      PSID          lpSid,
    #   _Out_opt_ LPTSTR        lpName,
    #   _Inout_   LPDWORD       cchName,
    #   _Out_opt_ LPTSTR        lpReferencedDomainName,
    #   _Inout_   LPDWORD       cchReferencedDomainName,
    #   _Out_     PSID_NAME_USE peUse
    # );
    ffi_lib :advapi32
    attach_function_private :LookupAccountSidW,
      [:lpcwstr, :pointer, :lpwstr, :lpdword, :lpwstr, :lpdword, :pointer], :win32_bool
  end
end

