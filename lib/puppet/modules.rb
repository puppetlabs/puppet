# Support for modules
class Puppet::Module

    TEMPLATES = "templates"
    FILES = "files"
    MANIFESTS = "manifests"

    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath
        dirs = Puppet[:modulepath].split(":")
        if ENV["PUPPETLIB"]
            dirs = ENV["PUPPETLIB"].split(":") + dirs
        end
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

    # Return a list of manifests (as absolute filenames) that match +pat+
    # with the current directory set to +cwd+. If the first component of
    # +pat+ does not contain any wildcards and is an existing module, return
    # a list of manifests in that module matching the rest of +pat+
    # Otherwise, try to find manifests matching +pat+ relative to +cwd+
    def self.find_manifests(pat, cwd = nil)
        cwd ||= Dir.getwd
        mod = find(pat)
        if mod
            return mod.manifests(pat)
        else
            abspat = File::expand_path(pat, cwd)
            files = Dir.glob(abspat)
            if files.size == 0
                files = Dir.glob(abspat + ".pp")
            end
            return files
        end
    end

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    def strip(file)
        n, rest = file.split(File::SEPARATOR, 2)
        rest = nil if rest && rest.empty?
        return rest
    end

    def template(file)
        return File::join(path, TEMPLATES, strip(file))
    end

    def files
        return File::join(path, FILES)
    end

    def manifests(pat)
        rest = strip(pat)
        rest ||= "init.pp"
        p = File::join(path, MANIFESTS, rest)
        files = Dir.glob(p)
        if files.size == 0
            files = Dir.glob(p + ".pp")
        end
        return files
    end

    private :initialize
end
