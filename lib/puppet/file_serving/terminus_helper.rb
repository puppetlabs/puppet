#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.
module Puppet::FileServing::TerminusHelper
    # Create model instances for all files in a fileset.
    def path2instances(request, path)
        args = [:links, :ignore, :recurse].inject({}) { |hash, param| hash[param] = request.options[param] if request.options[param]; hash }
        Puppet::FileServing::Fileset.new(path, args).files.collect do |file|
            inst = model.new(path, :relative_path => file)
            inst.links = request.options[:links] if request.options[:links]
            inst
        end
    end
end
