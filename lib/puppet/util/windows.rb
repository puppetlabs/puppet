module Puppet::Util::Windows
  if Puppet::Util::Platform.windows?
    require 'puppet/util/windows/error'
    require 'puppet/util/windows/security'
    require 'puppet/util/windows/user'
    require 'puppet/util/windows/process'
    require 'puppet/util/windows/file'
  end
  require 'puppet/util/windows/registry'
end
