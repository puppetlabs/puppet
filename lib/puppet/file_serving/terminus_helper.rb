#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.
module Puppet::FileServing::TerminusHelper
    # Create model instances for all files in a fileset.
    def path2instances(request, *paths)
        filesets = paths.collect do |path|
            # Filesets support indirector requests as an options collection
            Puppet::FileServing::Fileset.new(path, request)
        end

        Puppet::FileServing::Fileset.merge(*filesets).collect do |file, base_path|
            inst = model.new(base_path, :relative_path => file)
            inst.checksum_type = request.options[:checksum_type] if request.options[:checksum_type]
            inst.links = request.options[:links] if request.options[:links]
            inst.collect
            inst
        end
    end
end
