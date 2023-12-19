# frozen_string_literal: true

require_relative '../../puppet/module_tool'

module Puppet::ModuleTool
  module Applications
    require_relative 'applications/application'
    require_relative 'applications/checksummer'
    require_relative 'applications/installer'
    require_relative 'applications/unpacker'
    require_relative 'applications/uninstaller'
    require_relative 'applications/upgrader'
  end
end
