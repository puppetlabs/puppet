require 'puppet/module'

class Puppet::Module
  module Tool
    module Applications
      require 'puppet/module_tool/applications/application'
      require 'puppet/module_tool/applications/builder'
      require 'puppet/module_tool/applications/checksummer'
      require 'puppet/module_tool/applications/cleaner'
      require 'puppet/module_tool/applications/generator'
      require 'puppet/module_tool/applications/installer'
      require 'puppet/module_tool/applications/searcher'
      require 'puppet/module_tool/applications/unpacker'
      require 'puppet/module_tool/applications/uninstaller'
    end
  end
end
