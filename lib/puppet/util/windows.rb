module Puppet::Util::Windows
  module ADSI
    class User; end
    class UserProfile; end
    class Group; end
  end
  module File; end
  module Registry
  end
  module SID
    class Principal; end
  end
  class EventLog; end

  if Puppet::Util::Platform.windows?
    # these reference platform specific gems
    require 'puppet/util/windows/api_types'
    require 'puppet/util/windows/string'
    require 'puppet/util/windows/error'
    require 'puppet/util/windows/com'
    require 'puppet/util/windows/sid'
    require 'puppet/util/windows/principal'
    require 'puppet/util/windows/file'
    require 'puppet/util/windows/security'
    require 'puppet/util/windows/user'
    require 'puppet/util/windows/process'
    require 'puppet/util/windows/root_certs'
    require 'puppet/util/windows/access_control_entry'
    require 'puppet/util/windows/access_control_list'
    require 'puppet/util/windows/security_descriptor'
    require 'puppet/util/windows/adsi'
    require 'puppet/util/windows/registry'
    require 'puppet/util/windows/eventlog'
  end
end
