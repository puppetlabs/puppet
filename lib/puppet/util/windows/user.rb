require 'puppet/util/windows'

require 'win32/security'
require 'facter'
require 'ffi'

module Puppet::Util::Windows::User
  include ::Windows::Security
  extend ::Windows::Security
  extend Puppet::Util::Windows::String
  extend FFI::Library

  def admin?
    majversion = Facter.value(:kernelmajversion)
    return false unless majversion

    # if Vista or later, check for unrestricted process token
    return Win32::Security.elevated_security? unless majversion.to_f < 6.0

    # otherwise 2003 or less
    check_token_membership
  end
  module_function :admin?

  def check_token_membership
    sid = 0.chr * 80
    size = [80].pack('L')
    member = 0.chr * 4

    unless CreateWellKnownSid(WinBuiltinAdministratorsSid, nil, sid, size)
      raise Puppet::Util::Windows::Error.new("Failed to create administrators SID")
    end

    unless IsValidSid(sid)
      raise Puppet::Util::Windows::Error.new("Invalid SID")
    end

    unless CheckTokenMembership(nil, sid, member)
      raise Puppet::Util::Windows::Error.new("Failed to check membership")
    end

    # Is administrators SID enabled in calling thread's access token?
    member.unpack('L')[0] == 1
  end
  module_function :check_token_membership

  def password_is?(name, password)
    logon_user(name, password)
    true
  rescue Puppet::Util::Windows::Error
    false
  end
  module_function :password_is?

  def logon_user(name, password, &block)
    fLOGON32_LOGON_NETWORK = 3
    fLOGON32_PROVIDER_DEFAULT = 0

    token_pointer = FFI::MemoryPointer.new(:handle, 1)
    if ! LogonUserW(wide_string(name), wide_string('.'), wide_string(password),
        fLOGON32_LOGON_NETWORK, fLOGON32_PROVIDER_DEFAULT, token_pointer)
      raise Puppet::Util::Windows::Error.new("Failed to logon user #{name.inspect}")
    end

    token = token_pointer.read_handle
    begin
      yield token if block_given?
    ensure
      CloseHandle(token)
    end
  end
  module_function :logon_user

  def load_profile(user, password)
    logon_user(user, password) do |token|
      pi = PROFILEINFO.new
      pi[:dwSize] = PROFILEINFO.size
      pi[:dwFlags] = 1 # PI_NOUI - prevents display of profile error msgs
      pi[:lpUserName] = FFI::MemoryPointer.from_string_to_wide_string(user)

      # Load the profile. Since it doesn't exist, it will be created
      if ! LoadUserProfileW(token, pi.pointer)
        raise Puppet::Util::Windows::Error.new("Failed to load user profile #{user.inspect}")
      end

      Puppet.debug("Loaded profile for #{user}")

      if ! UnloadUserProfile(token, pi[:hProfile])
        raise Puppet::Util::Windows::Error.new("Failed to unload user profile #{user.inspect}")
      end
    end
  end
  module_function :load_profile

  ffi_convention :stdcall

  # http://msdn.microsoft.com/en-us/library/windows/desktop/aa378184(v=vs.85).aspx
  # BOOL LogonUser(
  #   _In_      LPTSTR lpszUsername,
  #   _In_opt_  LPTSTR lpszDomain,
  #   _In_opt_  LPTSTR lpszPassword,
  #   _In_      DWORD dwLogonType,
  #   _In_      DWORD dwLogonProvider,
  #   _Out_     PHANDLE phToken
  # );
  ffi_lib :advapi32
  attach_function_private :LogonUserW,
    [:lpwstr, :lpwstr, :lpwstr, :dword, :dword, :phandle], :bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/ms724211(v=vs.85).aspx
  # BOOL WINAPI CloseHandle(
  #   _In_  HANDLE hObject
  # );
  ffi_lib 'kernel32'
  attach_function_private :CloseHandle, [:handle], :bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/bb773378(v=vs.85).aspx
  # typedef struct _PROFILEINFO {
  #   DWORD  dwSize;
  #   DWORD  dwFlags;
  #   LPTSTR lpUserName;
  #   LPTSTR lpProfilePath;
  #   LPTSTR lpDefaultPath;
  #   LPTSTR lpServerName;
  #   LPTSTR lpPolicyPath;
  #   HANDLE hProfile;
  # } PROFILEINFO, *LPPROFILEINFO;
  # technically
  # NOTE: that for structs, buffer_* (lptstr alias) cannot be used
  class PROFILEINFO < FFI::Struct
    layout :dwSize, :dword,
           :dwFlags, :dword,
           :lpUserName, :pointer,
           :lpProfilePath, :pointer,
           :lpDefaultPath, :pointer,
           :lpServerName, :pointer,
           :lpPolicyPath, :pointer,
           :hProfile, :handle
  end

  # http://msdn.microsoft.com/en-us/library/windows/desktop/bb762281(v=vs.85).aspx
  # BOOL WINAPI LoadUserProfile(
  #   _In_     HANDLE hToken,
  #   _Inout_  LPPROFILEINFO lpProfileInfo
  # );
  ffi_lib :userenv
  attach_function_private :LoadUserProfileW,
    [:handle, :pointer], :bool

  # http://msdn.microsoft.com/en-us/library/windows/desktop/bb762282(v=vs.85).aspx
  # BOOL WINAPI UnloadUserProfile(
  #   _In_  HANDLE hToken,
  #   _In_  HANDLE hProfile
  # );
  ffi_lib :userenv
  attach_function_private :UnloadUserProfile,
    [:handle, :handle], :bool
end
