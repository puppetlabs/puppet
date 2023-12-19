# frozen_string_literal: true

require_relative '../../puppet/module_tool'

module Puppet::ModuleTool
  module Errors
    require_relative 'errors/base'
    require_relative 'errors/installer'
    require_relative 'errors/uninstaller'
    require_relative 'errors/upgrader'
    require_relative 'errors/shared'
  end
end
