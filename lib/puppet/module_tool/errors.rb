require 'puppet/module_tool'

module Puppet::ModuleTool
  module Errors
    require 'puppet/module_tool/errors/base'
    require 'puppet/module_tool/errors/installer'
    require 'puppet/module_tool/errors/uninstaller'
    require 'puppet/module_tool/errors/upgrader'
    require 'puppet/module_tool/errors/shared'
  end
end
