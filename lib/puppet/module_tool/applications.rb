require 'puppet/module_tool'

module Puppet::ModuleTool
  module Applications
    require 'puppet/module_tool/applications/application'
    require 'puppet/module_tool/applications/builder'
    require 'puppet/module_tool/applications/checksummer'
    require 'puppet/module_tool/applications/installer'
    require 'puppet/module_tool/applications/searcher'
    require 'puppet/module_tool/applications/unpacker'
    require 'puppet/module_tool/applications/uninstaller'
    require 'puppet/module_tool/applications/upgrader'
  end
end
