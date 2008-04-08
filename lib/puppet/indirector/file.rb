require 'puppet/indirector/terminus'

# An empty terminus type, meant to just return empty objects.
class Puppet::Indirector::File < Puppet::Indirector::Terminus
    # Remove files on disk.
    def destroy(name)
        if respond_to?(:path)
            path = path(name)
        else
            path = name
        end
        raise Puppet::Error.new("File %s does not exist; cannot destroy" % [name]) unless File.exist?(path)

        begin
            File.unlink(path)
        rescue => detail
            raise Puppet::Error, "Could not remove %s: %s" % [name, detail]
        end
    end

    # Return a model instance for a given file on disk.
    def find(name)
        if respond_to?(:path)
            path = path(name)
        else
            path = name
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
    def save(file)
        if respond_to?(:path)
            path = path(file.name)
        else
            path = file.path
        end
        dir = File.dirname(path)

        raise Puppet::Error.new("Cannot save %s; parent directory %s does not exist" % [file, dir]) unless File.directory?(dir)

        begin
            File.open(path, "w") { |f| f.print file.content }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [file, detail]
        end
    end
end
