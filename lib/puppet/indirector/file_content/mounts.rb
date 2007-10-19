#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/file_content'
require 'puppet/indirector/code'

class Puppet::Indirector::FileContent::Mounts < Puppet::Indirector::Code
    desc "Retrieve file contents using Puppet's fileserver."

    include Puppet::FileServing::TerminusHelper

    # This way it can be cleared or whatever and we aren't retaining
    # a reference to the old one.
    def configuration
        Puppet::FileServing::Configuration.create
    end

    def find(key)
        uri = key2uri(key)

        return nil unless path = configuration.file_path(uri.path) and FileTest.exists?(path)

        Puppet::FileServing::Content.new path
    end
end
