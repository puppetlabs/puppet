require 'puppet/util/windows'

module Puppet::Util::Windows
  module SID
    require 'ffi'
    extend FFI::Library

    # missing from Windows::Error
    ERROR_NONE_MAPPED           = 1332
    ERROR_INVALID_SID_STRUCTURE = 1337

    # Well Known SIDs
    Null                        = 'S-1-0'
    Nobody                      = 'S-1-0-0'
    World                       = 'S-1-1'
    Everyone                    = 'S-1-1-0'
    Local                       = 'S-1-2'
    Creator                     = 'S-1-3'
    CreatorOwner                = 'S-1-3-0'
    CreatorGroup                = 'S-1-3-1'
    CreatorOwnerServer          = 'S-1-3-2'
    CreatorGroupServer          = 'S-1-3-3'
    NonUnique                   = 'S-1-4'
    Nt                          = 'S-1-5'
    Dialup                      = 'S-1-5-1'
    Network                     = 'S-1-5-2'
    Batch                       = 'S-1-5-3'
    Interactive                 = 'S-1-5-4'
    Service                     = 'S-1-5-6'
    Anonymous                   = 'S-1-5-7'
    Proxy                       = 'S-1-5-8'
    EnterpriseDomainControllers = 'S-1-5-9'
    PrincipalSelf               = 'S-1-5-10'
    AuthenticatedUsers          = 'S-1-5-11'
    RestrictedCode              = 'S-1-5-12'
    TerminalServerUsers         = 'S-1-5-13'
    LocalSystem                 = 'S-1-5-18'
    NtLocal                     = 'S-1-5-19'
    NtNetwork                   = 'S-1-5-20'
    BuiltinAdministrators       = 'S-1-5-32-544'
    BuiltinUsers                = 'S-1-5-32-545'
    Guests                      = 'S-1-5-32-546'
    PowerUsers                  = 'S-1-5-32-547'
    AccountOperators            = 'S-1-5-32-548'
    ServerOperators             = 'S-1-5-32-549'
    PrintOperators              = 'S-1-5-32-550'
    BackupOperators             = 'S-1-5-32-551'
    Replicators                 = 'S-1-5-32-552'

    # Convert an account name, e.g. 'Administrators' into a SID string,
    # e.g. 'S-1-5-32-544'. The name can be specified as 'Administrators',
    # 'BUILTIN\Administrators', or 'S-1-5-32-544', and will return the
    # SID. Returns nil if the account doesn't exist.
    def name_to_sid(name)
      sid = name_to_sid_object(name)

      sid ? sid.sid : nil
    end
    module_function :name_to_sid

    # Convert an account name, e.g. 'Administrators' into a SID object,
    # e.g. 'S-1-5-32-544'. The name can be specified as 'Administrators',
    # 'BUILTIN\Administrators', or 'S-1-5-32-544', and will return the
    # SID object. Returns nil if the account doesn't exist.
    # This method returns a SID::Principal with the account, domain, SID, etc
    def name_to_sid_object(name)
      # Apparently, we accept a symbol..
      name = name.to_s.strip if name

      # if name is a SID string, convert it to raw bytes for use with lookup_account_sid
      raw_sid_bytes = nil
      begin
        string_to_sid_ptr(name) do |sid_ptr|
          valid = ! sid_ptr.nil? && ! sid_ptr.null?
          raw_sid_bytes = sid_ptr.read_array_of_uchar(get_length_sid(sid_ptr))
        end
      rescue
      end

      raw_sid_bytes ? Principal.lookup_account_sid(raw_sid_bytes) : Principal.lookup_account_name(name)
    rescue
      nil
    end
    module_function :name_to_sid_object

    # Converts an octet string array of bytes to a SID object,
    # e.g. [1, 1, 0, 0, 0, 0, 0, 5, 18, 0, 0, 0] is the representation for
    # S-1-5-18, the local 'SYSTEM' account.
    # Raises an Error for nil or non-array input.
    # This method returns a SID::Principal with the account, domain, SID, etc
    def octet_string_to_sid_object(bytes)
      if !bytes || !bytes.respond_to?('pack') || bytes.empty?
        raise Puppet::Util::Windows::Error.new("Octet string must be an array of bytes")
      end

      Principal.lookup_account_sid(bytes)
    end
    module_function :octet_string_to_sid_object

    # Convert a SID string, e.g. "S-1-5-32-544" to a name,
    # e.g. 'BUILTIN\Administrators'. Returns nil if an account
    # for that SID does not exist.
    def sid_to_name(value)

      sid_bytes = []
      begin
        string_to_sid_ptr(value) do |ptr|
          valid = ! ptr.nil? && ! ptr.null?
          sid_bytes = ptr.read_array_of_uchar(get_length_sid(ptr))
        end
      rescue Puppet::Util::Windows::Error => e
        raise if e.code != ERROR_INVALID_SID_STRUCTURE
      end

      Principal.lookup_account_sid(sid_bytes).domain_account
    rescue
      nil
    end
    module_function :sid_to_name

    # https://stackoverflow.com/a/1792930 - 68 bytes, 184 characters in a string
    MAXIMUM_SID_STRING_LENGTH = 184

    # Convert a SID pointer to a SID string, e.g. "S-1-5-32-544".
    def sid_ptr_to_string(psid)
      if ! psid.kind_of?(FFI::Pointer) || IsValidSid(psid) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Invalid SID")
      end

      sid_string = nil
      FFI::MemoryPointer.new(:pointer, 1) do |buffer_ptr|
        if ConvertSidToStringSidW(psid, buffer_ptr) == FFI::WIN32_FALSE
          raise Puppet::Util::Windows::Error.new("Failed to convert binary SID")
        end

        buffer_ptr.read_win32_local_pointer do |wide_string_ptr|
          if wide_string_ptr.null?
            raise Puppet::Error.new("ConvertSidToStringSidW failed to allocate buffer for sid")
          end

          sid_string = wide_string_ptr.read_arbitrary_wide_string_up_to(MAXIMUM_SID_STRING_LENGTH)
        end
      end

      sid_string
    end
    module_function :sid_ptr_to_string

    # Convert a SID string, e.g. "S-1-5-32-544" to a pointer (containing the
    # address of the binary SID structure). The returned value can be used in
    # Win32 APIs that expect a PSID, e.g. IsValidSid. The account for this
    # SID may or may not exist.
    def string_to_sid_ptr(string_sid, &block)
      FFI::MemoryPointer.from_string_to_wide_string(string_sid) do |lpcwstr|
        FFI::MemoryPointer.new(:pointer, 1) do |sid_ptr_ptr|

          if ConvertStringSidToSidW(lpcwstr, sid_ptr_ptr) == FFI::WIN32_FALSE
            raise Puppet::Util::Windows::Error.new("Failed to convert string SID: #{string_sid}")
          end

          sid_ptr_ptr.read_win32_local_pointer do |sid_ptr|
            yield sid_ptr
          end
        end
      end

      # yielded sid_ptr has already had LocalFree called, nothing to return
      nil
    end
    module_function :string_to_sid_ptr

    # Return true if the string is a valid SID, e.g. "S-1-5-32-544", false otherwise.
    def valid_sid?(string_sid)
      valid = false

      begin
        string_to_sid_ptr(string_sid) { |ptr| valid = ! ptr.nil? && ! ptr.null? }
      rescue Puppet::Util::Windows::Error => e
        raise if e.code != ERROR_INVALID_SID_STRUCTURE
      end

      valid
    end
    module_function :valid_sid?

    def get_length_sid(sid_ptr)
      # MSDN states IsValidSid should be called on pointer first
      if ! sid_ptr.kind_of?(FFI::Pointer) || IsValidSid(sid_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Invalid SID")
      end

      GetLengthSid(sid_ptr)
    end
    module_function :get_length_sid

    ffi_convention :stdcall

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa379151(v=vs.85).aspx
    # BOOL WINAPI IsValidSid(
    #   _In_  PSID pSid
    # );
    ffi_lib :advapi32
    attach_function_private :IsValidSid,
      [:pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376399(v=vs.85).aspx
    # BOOL ConvertSidToStringSid(
    #   _In_   PSID Sid,
    #   _Out_  LPTSTR *StringSid
    # );
    ffi_lib :advapi32
    attach_function_private :ConvertSidToStringSidW,
      [:pointer, :pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa376402(v=vs.85).aspx
    # BOOL WINAPI ConvertStringSidToSid(
    #   _In_   LPCTSTR StringSid,
    #   _Out_  PSID *Sid
    # );
    ffi_lib :advapi32
    attach_function_private :ConvertStringSidToSidW,
      [:lpcwstr, :pointer], :win32_bool

    # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446642(v=vs.85).aspx
    # DWORD WINAPI GetLengthSid(
    #   _In_ PSID pSid
    # );
    ffi_lib :advapi32
    attach_function_private :GetLengthSid, [:pointer], :dword
  end
end
