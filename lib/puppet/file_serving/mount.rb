#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/network/authstore'
require 'puppet/util/logging'
require 'puppet/util/cacher'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'

# Broker access to the filesystem, converting local URIs into metadata
# or content objects.
class Puppet::FileServing::Mount < Puppet::Network::AuthStore
    include Puppet::Util::Logging

    attr_reader :name
    
    # Determine the environment to use, if any.
    def environment(node_name)
        if node_name and node = Puppet::Node.find(node_name)
            Puppet::Node::Environment.new(node.environment)
        else
            Puppet::Node::Environment.new
        end
    end

    def find(path, options)
        raise NotImplementedError
    end

    # Create our object.  It must have a name.
    def initialize(name)
        unless name =~ %r{^[-\w]+$}
            raise ArgumentError, "Invalid mount name format '%s'" % name
        end
        @name = name

        super()
    end

    def search(path, options)
        raise NotImplementedError
    end

    def to_s
        "mount[%s]" % @name
    end

    # A noop.
    def validate
    end
end
