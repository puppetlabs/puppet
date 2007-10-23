#
#  Created by Luke Kanies on 2007-10-22.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving'
require 'puppet/file_serving/fileset'

# Define some common methods for FileServing termini.
module Puppet::FileServing::TerminusHelper
    # Create model instances for all files in a fileset.
    def path2instances(path, options = {})
        args = [:links, :ignore, :recurse].inject({}) { |hash, param| hash[param] = options[param] if options[param]; hash }
        Puppet::FileServing::Fileset.new(path, args).files.collect { |file| model.new(file) }
    end
end
