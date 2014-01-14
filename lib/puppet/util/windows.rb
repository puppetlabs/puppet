module Puppet::Util::Windows
  if Puppet::Util::Platform.windows?
    # these reference platform specific gems
    require 'puppet/util/windows/error'
    require 'puppet/util/windows/sid'
    require 'puppet/util/windows/security'
    require 'puppet/util/windows/user'
    require 'puppet/util/windows/process'
    require 'puppet/util/windows/string'
    require 'puppet/util/windows/file'
    require 'puppet/util/windows/root_certs'
    require 'puppet/util/windows/access_control_entry'
    require 'puppet/util/windows/access_control_list'
    require 'puppet/util/windows/security_descriptor'
  end
  require 'puppet/util/windows/registry'
end
