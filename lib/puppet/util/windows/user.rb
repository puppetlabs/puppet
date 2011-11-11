require 'puppet/util/windows'

module Puppet::Util::Windows::User
  def admin?
    require 'sys/admin'
    require 'win32/security'
    require 'facter'

    majversion = Facter.value(:kernelmajversion)
    return false unless majversion

    # if Vista or later, check for unrestricted process token
    return Win32::Security.elevated_security? unless majversion.to_f < 6.0

    group = Sys::Admin.get_group("Administrators", :sid => Win32::Security::SID::BuiltinAdministrators)
    group and group.members.index(Sys::Admin.get_login) != nil
  end
  module_function :admin?
end
