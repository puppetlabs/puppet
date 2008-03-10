require 'puppet/indirector/file'

class Puppet::Indirector::SslFile < Puppet::Indirector::Terminus
    def self.store_in(setting)
        @directory_setting = setting
    end

    class << self
        attr_reader :directory_setting
    end

    def self.collection_directory
        raise(Puppet::DevError, "No setting defined for %s" % self) unless @directory_setting
        Puppet.settings[@directory_setting]
    end

    def initialize
        Puppet.settings.use(:ssl)
    end

    # Use a setting to determine our path.
    def path(name)
        File.join(collection_directory, name.to_s + ".pem")
    end

    def destroy(file)
        path = path(file.name)
        raise Puppet::Error.new("File %s does not exist; cannot destroy" % [file]) unless FileTest.exist?(path)

        begin
            File.unlink(path)
        rescue => detail
            raise Puppet::Error, "Could not remove %s: %s" % [file, detail]
        end
    end

    def find(name)
        path = path(name)

        return nil unless FileTest.exist?(path)

        result = model.new(name)
        result.read(path)
        result
    end

    def save(file)
        path = path(file.name)
        dir = File.dirname(path)

        raise Puppet::Error.new("Cannot save %s; parent directory %s does not exist" % [file, dir]) unless FileTest.directory?(dir)
        raise Puppet::Error.new("Cannot save %s; parent directory %s does not exist" % [file, dir]) unless FileTest.writable?(dir)

        begin
            File.open(path, "w") { |f| f.print file.to_s }
        rescue => detail
            raise Puppet::Error, "Could not write %s: %s" % [file, detail]
        end
    end

    private

    def collection_directory
        self.class.collection_directory
    end
end
