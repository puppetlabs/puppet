require 'puppet/indirector/terminus'

# The base class for YAML indirection termini.
class Puppet::Indirector::Yaml < Puppet::Indirector::Terminus
    # Read a given name's file in and convert it from YAML.
    def find(request)
        file = path(request.key)
        return nil unless FileTest.exist?(file)

        begin
            return from_yaml(File.read(file))
        rescue => detail
            raise Puppet::Error, "Could not read YAML data for %s %s: %s" % [indirection.name, request.key, detail]
        end
    end

    # Convert our object to YAML and store it to the disk.
    def save(request)
        raise ArgumentError.new("You can only save objects that respond to :name") unless request.instance.respond_to?(:name)

        file = path(request.key)

        basedir = File.dirname(file)

        # This is quite likely a bad idea, since we're not managing ownership or modes.
        unless FileTest.exist?(basedir)
            Dir.mkdir(basedir)
        end

        begin
            File.open(file, "w", 0660) { |f| f.print to_yaml(request.instance) }
        rescue TypeError => detail
            Puppet.err "Could not save %s %s: %s" % [self.name, request.key, detail]
        end
    end

    # Return the path to a given node's file.
    def path(name)
        File.join(Puppet[:yamldir], self.class.indirection_name.to_s, name.to_s + ".yaml")
    end

    private

    def from_yaml(text)
        YAML.load(text)
    end

    def to_yaml(object)
        YAML.dump(object)
    end
end
