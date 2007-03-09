# Support for modules
class Puppet::Module

    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath
        dirs = ENV["PUPPETLIB"].split(":") + Puppet[:modulepath].split(":")
        dirs.select do |p|
            p =~ /^#{File::SEPARATOR}/ && File::directory?(p)
        end
    end

    # Find and return the +module+ that +path+ belongs to. If +path+ is
    # absolute, or if there is no module whose name is the first component
    # of +path+, return +nil+
    def self.find(path)
        if path =~ %r/^#{File::SEPARATOR}/
            return nil
        end

        modname, rest = path.split(File::SEPARATOR, 2)
        return nil if modname.nil? || modname.empty?

        modpath = modulepath.collect { |p|
            File::join(p, modname)
        }.find { |f| File::directory?(f) }
        return nil unless modpath

        return self.new(modname, modpath)
    end

    # Instance methods

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    private :initialize
end
