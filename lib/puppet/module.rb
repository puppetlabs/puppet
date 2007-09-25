# Support for modules
class Puppet::Module

    TEMPLATES = "templates"
    FILES = "files"
    MANIFESTS = "manifests"

    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath(environment = nil)
        dirs = Puppet.settings.value(:modulepath, environment).split(":")
        if ENV["PUPPETLIB"]
            dirs = ENV["PUPPETLIB"].split(":") + dirs
        else
        end
        dirs.select do |p|
            p =~ /^#{File::SEPARATOR}/ && File::directory?(p)
        end
    end

    # Find and return the +module+ that +path+ belongs to. If +path+ is
    # absolute, or if there is no module whose name is the first component
    # of +path+, return +nil+
    def self.find(modname, environment = nil)
        if modname =~ %r/^#{File::SEPARATOR}/
            return nil
        end

        modpath = modulepath(environment).collect { |p|
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
    def self.find_template(template, environment = nil)
        if template =~ /^#{File::SEPARATOR}/
            return template
        end

        path, file = split_path(template)

        # Because templates don't have an assumed template name, like manifests do,
        # we treat templates with no name as being templates in the main template
        # directory.
        if file.nil?
            mod = nil
        else
            mod = find(path, environment)
        end
        if mod
            return mod.template(file)
        else
            return File.join(Puppet.settings.value(:templatedir, environment), template)
        end
    end

    # Return a list of manifests (as absolute filenames) that match +pat+
    # with the current directory set to +cwd+. If the first component of
    # +pat+ does not contain any wildcards and is an existing module, return
    # a list of manifests in that module matching the rest of +pat+
    # Otherwise, try to find manifests matching +pat+ relative to +cwd+
    def self.find_manifests(start, options = {})
        cwd = options[:cwd] || Dir.getwd
        path, pat = split_path(start)
        mod = find(path, options[:environment])
        if mod
            return mod.manifests(pat)
        else
            abspat = File::expand_path(start, cwd)
            files = Dir.glob(abspat).reject { |f| FileTest.directory?(f) }
            if files.size == 0
                files = Dir.glob(abspat + ".pp").reject { |f| FileTest.directory?(f) }
            end
            return files
        end
    end

    # Split the path into the module and the rest of the path.
    def self.split_path(path)
        if path =~ %r/^#{File::SEPARATOR}/
            return nil
        end

        modname, rest = path.split(File::SEPARATOR, 2)
        return nil if modname.nil? || modname.empty?
        return modname, rest
    end

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    def template(file)
        return File::join(path, TEMPLATES, file)
    end

    def files
        return File::join(path, FILES)
    end

    # Return the list of manifests matching the given glob pattern,
    # defaulting to 'init.pp' for empty modules.
    def manifests(rest)
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
