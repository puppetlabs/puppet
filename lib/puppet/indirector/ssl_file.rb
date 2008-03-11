require 'puppet/indirector/file'

class Puppet::Indirector::SslFile < Puppet::Indirector::Terminus
    def self.store_in(setting)
        @directory_setting = setting
    end

    class << self
        attr_reader :directory_setting
    end

    # The full path to where we should store our files.
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

    # Remove our file.
    def destroy(file)
        path = path(file.name)
        raise Puppet::Error.new("File %s does not exist; cannot destroy" % [file]) unless FileTest.exist?(path)

        begin
            File.unlink(path)
        rescue => detail
            raise Puppet::Error, "Could not remove %s: %s" % [file, detail]
        end
    end

    # Find the file on disk, returning an instance of the model.
    def find(name)
        path = path(name)

        return nil unless FileTest.exist?(path)

        result = model.new(name)
        result.read(path)
        result
    end

    # Save our file to disk.
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

    # A demeterish pointer to the collection directory.
    def collection_directory
        self.class.collection_directory
    end
end
