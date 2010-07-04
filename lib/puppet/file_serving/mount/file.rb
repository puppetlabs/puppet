require 'puppet/util/cacher'

require 'puppet/file_serving/mount'

class Puppet::FileServing::Mount::File < Puppet::FileServing::Mount
    class << self
        include Puppet::Util::Cacher

        cached_attr(:localmap) do
            {   "h" =>  Facter.value("hostname"),
                "H" => [Facter.value("hostname"),
                        Facter.value("domain")].join("."),
                "d" =>  Facter.value("domain")
            }
        end
    end

    def complete_path(relative_path, node)
        full_path = path(node)

        raise ArgumentError.new("Mounts without paths are not usable") unless full_path

        # If there's no relative path name, then we're serving the mount itself.
        return full_path unless relative_path

        file = ::File.join(full_path, relative_path)

        if !(FileTest.exist?(file) or FileTest.symlink?(file))
            Puppet.info("File does not exist or is not accessible: #{file}")
            return nil
        end

        return file
    end

    # Return an instance of the appropriate class.
    def find(short_file, request)
        complete_path(short_file, request.node)
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

    def search(path, request)
        return nil unless path = complete_path(path, request.node)
        return [path]
    end

    # Verify our configuration is valid.  This should really check to
    # make sure at least someone will be allowed, but, eh.
    def validate
        raise ArgumentError.new("Mounts without paths are not usable") if @path.nil?
    end

    private

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
