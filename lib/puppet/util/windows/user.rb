require 'puppet/util/windows'

require 'win32/security'

module Puppet::Util::Windows::User
  include Windows::Security
  extend Windows::Security

  def admin?
    require 'facter'

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
end
