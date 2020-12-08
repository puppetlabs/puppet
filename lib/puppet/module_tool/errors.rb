require_relative '../../puppet/module_tool'

module Puppet::ModuleTool
  module Errors
    require_relative '../../puppet/module_tool/errors/base'
    require_relative '../../puppet/module_tool/errors/installer'
    require_relative '../../puppet/module_tool/errors/uninstaller'
    require_relative '../../puppet/module_tool/errors/upgrader'
    require_relative '../../puppet/module_tool/errors/shared'
  end
end
