#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util/uri_helper'
require 'puppet/indirector/terminus'

# Look files up in Puppet modules.
class Puppet::Indirector::ModuleFiles < Puppet::Indirector::Terminus
    include Puppet::Util::URIHelper

    # Find our key in a module.
    def find(key, options = {})
        uri = key2uri(key)

        # Strip off /modules if it's there -- that's how requests get routed to this terminus.
        # Also, strip off the leading slash if present.
        module_name, relative_path = uri.path.sub(/^\/modules\b/, '').sub(%r{^/}, '').split(File::Separator, 2)

        # And use the environment to look up the module.
        return nil unless mod = find_module(module_name, options[:node])

        path = File.join(mod.files, relative_path)

        return nil unless FileTest.exists?(path)

        return model.new(path)
    end

    private
    
    # Determine the environment to use, if any.
    def environment(node_name)
        if node_name and node = Puppet::Node.find(node_name)
            node.environment
        elsif env = Puppet.settings[:environment] and env != ""
            env
        else
            nil
        end
    end

    # Try to find our module.
    def find_module(module_name, node_name)
        Puppet::Module::find(module_name, environment(node_name))
    end
end
