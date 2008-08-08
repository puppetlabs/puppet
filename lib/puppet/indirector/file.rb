require 'puppet/indirector/terminus'

# An empty terminus type, meant to just return empty objects.
class Puppet::Indirector::File < Puppet::Indirector::Terminus
    # Remove files on disk.
    def destroy(request)
        if respond_to?(:path)
            path = path(request.key)
        else
            path = request.key
        end
        raise Puppet::Error.new("File %s does not exist; cannot destroy" % [request.key]) unless File.exist?(path)

        Puppet.notice "Removing file %s %s at '%s'" % [model, request.key, path]
        begin
            File.unlink(path)
        rescue => detail
            raise Puppet::Error, "Could not remove %s: %s" % [request.key, detail]
        end
    end

    # Return a model instance for a given file on disk.
    def find(request)
        if respond_to?(:path)
            path = path(request.key)
        else
            path = request.key
        end

        return nil unless File.exist?(path)

        begin
            content = File.read(path)
        rescue => detail
            raise Puppet::Error, "Could not retrieve path %s: %s" % [path, detail]
        end

        return model.new(content)
    end

    # Save a new file to disk.
    def save(request)
        if respond_to?(:path)
            path = path(request.key)
        else
            path = request.key
        end
        dir = File.dirname(path)

        raise Puppet::Error.new("Cannot save %s; parent directory %s does not exist" % [request.key, dir]) unless File.directory?(dir)

        begin
            File.open(path, "w") { |f| f.print request.instance.content }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [request.key, detail]
        end
    end
end
