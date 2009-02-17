#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.
module Puppet::FileServing::TerminusHelper
    # Create model instances for all files in a fileset.
    def path2instances(request, *paths)
        args = [:links, :ignore, :recurse].inject({}) do |hash, param|
            if request.options.include?(param) # use 'include?' so the values can be false
                hash[param] = request.options[param]
            elsif request.options.include?(param.to_s)
                hash[param] = request.options[param.to_s]
            end
            hash[param] = true if hash[param] == "true"
            hash[param] = false if hash[param] == "false"
            hash
        end
        filesets = paths.collect do |path|
            Puppet::FileServing::Fileset.new(path, args)
        end

        Puppet::FileServing::Fileset.merge(*filesets).collect do |file, base_path|
            inst = model.new(base_path, :relative_path => file)
            inst.links = request.options[:links] if request.options[:links]
            inst.collect
            inst
        end
    end
end
