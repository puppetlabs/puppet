require 'puppet/util/windows'

require 'win32/security'
require 'facter'

module Puppet::Util::Windows::User
  include ::Windows::Security
  extend ::Windows::Security

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

    logon_user = Win32API.new("advapi32", "LogonUser", ['P', 'P', 'P', 'L', 'L', 'P'], 'L')
    close_handle = Win32API.new("kernel32", "CloseHandle", ['L'], 'B')

    token = 0.chr * 4
    if logon_user.call(name, ".", password, fLOGON32_LOGON_NETWORK, fLOGON32_PROVIDER_DEFAULT, token) == 0
      raise Puppet::Util::Windows::Error.new("Failed to logon user #{name.inspect}")
    end

    token = token.unpack('L')[0]
    begin
      yield token if block_given?
    ensure
      close_handle.call(token)
    end
  end
  module_function :logon_user

  def load_profile(user, password)
    logon_user(user, password) do |token|
      # Set up the PROFILEINFO structure that will be used to load the
      # new user's profile
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
      fPI_NOUI = 1
      profile = 0.chr * 4
      pi = [4 * 8, fPI_NOUI, user, nil, nil, nil, nil, profile].pack('LLPPPPPP')

      load_user_profile   = Win32API.new('userenv', 'LoadUserProfile', ['L', 'P'], 'L')
      unload_user_profile = Win32API.new('userenv', 'UnloadUserProfile', ['L', 'L'], 'L')

      # Load the profile. Since it doesn't exist, it will be created
      if load_user_profile.call(token, pi) == 0
        raise Puppet::Util::Windows::Error.new("Failed to load user profile #{user.inspect}")
      end

      Puppet.debug("Loaded profile for #{user}")

      profile = pi.unpack('LLLLLLLL').last
      if unload_user_profile.call(token, profile) == 0
        raise Puppet::Util::Windows::Error.new("Failed to unload user profile #{user.inspect}")
      end
    end
  end
  module_function :load_profile
end
