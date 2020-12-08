require_relative '../../puppet/module_tool'

module Puppet::ModuleTool
  module Applications
    require_relative '../../puppet/module_tool/applications/application'
    require_relative '../../puppet/module_tool/applications/checksummer'
    require_relative '../../puppet/module_tool/applications/installer'
    require_relative '../../puppet/module_tool/applications/unpacker'
    require_relative '../../puppet/module_tool/applications/uninstaller'
    require_relative '../../puppet/module_tool/applications/upgrader'
  end
end
