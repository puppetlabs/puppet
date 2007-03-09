# Support for modules
class Puppet::Module

    TEMPLATES = "templates"
    FILES = "files"

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

    # Find the concrete file denoted by +file+. If +file+ is absolute,
    # return it directly. Otherwise try to find it as a template in a
    # module. If that fails, return it relative to the +templatedir+ config
    # param.
    # In all cases, an absolute path is returned, which does not
    # necessarily refer to an existing file
    def self.find_template(file)
        if file =~ /^#{File::SEPARATOR}/
            return file
        end

        mod = find(file)
        if mod
            return mod.template(file)
        else
            return File.join(Puppet[:templatedir], file)
        end
    end

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    def strip(file)
        n, rest = file.split(File::SEPARATOR, 2)
        return rest
    end

    def template(file)
        return File::join(path, TEMPLATES, strip(file))
    end

    def files
        return File::join(path, FILES)
    end

    private :initialize
end
