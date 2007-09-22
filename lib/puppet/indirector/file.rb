require 'puppet/indirector/terminus'

# An empty terminus type, meant to just return empty objects.
class Puppet::Indirector::File < Puppet::Indirector::Terminus
    def destroy(file)
        raise Puppet::Error.new("File %s does not exist; cannot destroy" % [file.name]) unless File.exist?(file.path)

        begin
            File.unlink(file.path)
        rescue => detail
            raise Puppet::Error, "Could not remove %s: %s" % [file.path, detail]
        end
    end

    def find(path)
        return nil unless File.exist?(path)

        begin
            content = File.read(path)
        rescue => detail
            raise Puppet::Error, "Could not retrieve path %s: %s" % [path, detail]
        end

        file = model.new(path)
        file.content = content
        return file
    end

    def save(file)
        dir = File.dirname(file.path)

        raise Puppet::Error.new("Cannot save %s; parent directory %s does not exist" % [file.name, dir]) unless File.directory?(dir)

        begin
            File.open(file.path, "w") { |f| f.print file.content }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [file.path, detail]
        end
    end
end
