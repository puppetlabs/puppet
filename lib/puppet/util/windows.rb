# frozen_string_literal: true

require_relative '../../puppet/util/platform'

module Puppet::Util::Windows
  module ADSI
    class ADSIObject; end
    class User < ADSIObject; end
    class UserProfile; end
    class Group < ADSIObject; end
  end

  module File; end

  module Registry
  end

  module Service
    DEFAULT_TIMEOUT = 30
  end

  module SID
    class Principal; end
  end

  class EventLog; end

  if Puppet::Util::Platform.windows?
    # Note: Setting codepage here globally ensures all strings returned via
    # WIN32OLE (Ruby's late-bound COM support) are encoded in Encoding::UTF_8
    #
    # Also, this does not modify the value of WIN32OLE.locale - which defaults
    # to 2048 (at least on US English Windows) and is not listed in the MS
    # locales table, here: https://msdn.microsoft.com/en-us/library/ms912047(v=winembedded.10).aspx
    require 'win32ole'; WIN32OLE.codepage = WIN32OLE::CP_UTF8

    # these reference platform specific gems
    require_relative '../../puppet/ffi/windows'
    require_relative 'windows/string'
    require_relative 'windows/error'
    require_relative 'windows/com'
    require_relative 'windows/sid'
    require_relative 'windows/principal'
    require_relative 'windows/file'
    require_relative 'windows/security'
    require_relative 'windows/user'
    require_relative 'windows/process'
    require_relative 'windows/root_certs'
    require_relative 'windows/access_control_entry'
    require_relative 'windows/access_control_list'
    require_relative 'windows/security_descriptor'
    require_relative 'windows/adsi'
    require_relative 'windows/registry'
    require_relative 'windows/eventlog'
    require_relative 'windows/service'
    require_relative 'windows/monkey_patches/process'
  end
end
