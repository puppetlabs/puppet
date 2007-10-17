#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/network/authstore'
require 'puppet/util/logging'
require 'puppet/file_serving'
require 'puppet/file_serving/metadata'
require 'puppet/file_serving/content'

# Broker access to the filesystem, converting local URIs into metadata
# or content objects.
class Puppet::FileServing::Mount < Puppet::Network::AuthStore
    include Puppet::Util::Logging

    attr_reader :name

    @@syncs = {}

    @@files = {}

    # Return a new mount with the same properties as +self+, except
    # with a different name and path.
    def copy(name, path)
        result = self.clone
        result.path = path
        result.instance_variable_set(:@name, name)
        return result
    end

    # Return a content instance for a given file.
    def content(short_file, client = nil)
        file_instance(Puppet::FileServing::Content, short_file, client)
    end

    # Return a fully qualified path, given a short path and
    # possibly a client name.
    def file_path(short, client = nil)
        p = path(client)
        raise ArgumentError.new("Mounts without paths are not usable") unless p
        File.join(p, short)
    end

    # Create out object.  It must have a name.
    def initialize(name, path = nil)
        unless name =~ %r{^[-\w]+$}
            raise ArgumentError, "Invalid mount name format '%s'" % name
        end
        @name = name

        if path
            self.path = path
        else
            @path = nil
        end

        super()
    end

    # Return a metadata instance with the appropriate information provided.
    def metadata(short_file, client = nil)
        file_instance(Puppet::FileServing::Metadata, short_file, client)
    end

    # Return the path as appropriate, expanding as necessary.
    def path(client = nil)
        if expandable?
            return expand(@path, client)
        else
            return @path
        end
    end

    # Set the path.
    def path=(path)
        # FIXME: For now, just don't validate paths with replacement
        # patterns in them.
        if path =~ /%./
            # Mark that we're expandable.
            @expandable = true
        else
            unless FileTest.exists?(path)
                raise ArgumentError, "%s does not exist" % path
            end
            unless FileTest.directory?(path)
                raise ArgumentError, "%s is not a directory" % path
            end
            unless FileTest.readable?(path)
                raise ArgumentError, "%s is not readable" % path
            end
            @expandable = false
        end
        @path = path
    end

    def sync(path)
        @@syncs[path] ||= Sync.new
        @@syncs[path]
    end

    def to_s
        "mount[%s]" % @name
    end

    # Verify our configuration is valid.  This should really check to
    # make sure at least someone will be allowed, but, eh.
    def valid?
        if name == MODULES
            return @path.nil?
        else
            return ! @path.nil?
        end
    end

    private

    # Create a map for a specific client.
    def clientmap(client)
        {
            "h" => client.sub(/\..*$/, ""), 
            "H" => client,
            "d" => client.sub(/[^.]+\./, "") # domain name
        }
    end

    # Replace % patterns as appropriate.
    def expand(path, client = nil)
        # This map should probably be moved into a method.
        map = nil

        if client
            map = clientmap(client)
        else
            Puppet.notice "No client; expanding '%s' with local host" %
                path
            # Else, use the local information
            map = localmap()
        end
        path.gsub(/%(.)/) do |v|
            key = $1
            if key == "%" 
                "%"
            else
                map[key] || v
            end
        end
    end

    # Do we have any patterns in our path, yo?
    def expandable?
        if defined? @expandable
            @expandable
        else
            false
        end
    end

    # Return an instance of the appropriate class.
    def file_instance(klass, short_file, client = nil)
        file = file_path(short_file, client)

        return nil unless FileTest.exists?(file)

        return klass.new(file)
    end

    # Cache this manufactured map, since if it's used it's likely
    # to get used a lot.
    def localmap
        unless defined? @@localmap
            @@localmap = {
                "h" =>  Facter.value("hostname"),
                "H" => [Facter.value("hostname"),
                        Facter.value("domain")].join("."),
                "d" =>  Facter.value("domain")
            }
        end
        @@localmap
    end
end
