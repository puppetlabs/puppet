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
    extend Puppet::Util::Cacher

    def self.localmap
        attr_cache(:localmap) { 
            {   "h" =>  Facter.value("hostname"),
                "H" => [Facter.value("hostname"),
                        Facter.value("domain")].join("."),
                "d" =>  Facter.value("domain")
            }
        }
    end

    attr_reader :name

    # Return a new mount with the same properties as +self+, except
    # with a different name and path.
    def copy(name, path)
        result = self.clone
        result.path = path
        result.instance_variable_set(:@name, name)
        return result
    end

    # Return an instance of the appropriate class.
    def file(short_file, options = {})
        file = file_path(short_file, options[:node])

        return nil unless FileTest.exists?(file)

        return file
    end

    # Return a fully qualified path, given a short path and
    # possibly a client name.
    def file_path(relative_path, node = nil)
        full_path = path(node)
        raise ArgumentError.new("Mounts without paths are not usable") unless full_path

        # If there's no relative path name, then we're serving the mount itself.
        return full_path unless relative_path

        return File.join(full_path, relative_path)
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

    # Return the path as appropriate, expanding as necessary.
    def path(node = nil)
        if expandable?
            return expand(@path, node)
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
            unless FileTest.directory?(path)
                raise ArgumentError, "%s does not exist or is not a directory" % path
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
        return ! @path.nil?
    end

    private

    # LAK:FIXME Move this method to the REST terminus hook.
    def authcheck(file, client, clientip)
        raise "This method should be replaced by a REST/terminus hook"
        # If we're local, don't bother passing in information.
        if local?
            client = nil
            clientip = nil
        end
        unless mount.allowed?(client, clientip)
            mount.warning "%s cannot access %s" %
                [client, file]
            raise Puppet::AuthorizationError, "Cannot access %s" % mount
        end
    end

    # Create a map for a specific node.
    def clientmap(node)
        {
            "h" => node.sub(/\..*$/, ""), 
            "H" => node,
            "d" => node.sub(/[^.]+\./, "") # domain name
        }
    end

    # Replace % patterns as appropriate.
    def expand(path, node = nil)
        # This map should probably be moved into a method.
        map = nil

        if node
            map = clientmap(node)
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

    # Cache this manufactured map, since if it's used it's likely
    # to get used a lot.
    def localmap
        self.class.localmap
    end
end
