# Support for modules
class Puppet::Module

    TEMPLATES = "templates"
    FILES = "files"
    MANIFESTS = "manifests"
    PLUGINS = "plugins"

    FILETYPES = [MANIFESTS, FILES, TEMPLATES, PLUGINS]

    # Search through a list of paths, yielding each found module in turn.
    def self.each_module(*paths)
        paths = paths.flatten.collect { |p| p.split(File::PATH_SEPARATOR) }.flatten

        yielded = {}
        paths.each do |dir|
            next unless FileTest.directory?(dir)

            Dir.entries(dir).each do |name|
                next if name =~ /^\./
                next if yielded.include?(name)

                module_path = File.join(dir, name)
                next unless FileTest.directory?(module_path)

                yielded[name] = true

                yield Puppet::Module.new(name)
            end
        end
    end

    # Return an array of paths by splitting the +modulepath+ config
    # parameter. Only consider paths that are absolute and existing
    # directories
    def self.modulepath(environment = nil)
        Puppet::Node::Environment.new(environment).modulepath
    end

    # Find and return the +module+ that +path+ belongs to. If +path+ is
    # absolute, or if there is no module whose name is the first component
    # of +path+, return +nil+
    def self.find(modname, environment = nil)
        return nil unless modname
        Puppet::Node::Environment.new(environment).module(modname)
    end

    attr_reader :name, :environment
    def initialize(name, environment = nil)
        @name = name
        if environment.is_a?(Puppet::Node::Environment)
            @environment = environment
        else
            @environment = Puppet::Node::Environment.new(environment)
        end
    end

    FILETYPES.each do |type|
        # A boolean method to let external callers determine if
        # we have files of a given type.
        define_method(type +'?') do
            return false unless path
            return false unless FileTest.exist?(subpath(type))
            return true
        end

        # A method for returning a given file of a given type.
        # e.g., file = mod.manifest("my/manifest.pp")
        #
        # If the file name is nil, then the base directory for the
        # file type is passed; this is used for fileserving.
        define_method(type.to_s.sub(/s$/, '')) do |file|
            return nil unless path

            # If 'file' is nil then they're asking for the base path.
            # This is used for things like fileserving.
            if file
                full_path = File.join(subpath(type), file)
            else
                full_path = subpath(type)
            end

            return nil unless FileTest.exist?(full_path)
            return full_path
        end
    end

    def exist?
        ! path.nil?
    end

    # Find the first 'files' directory.  This is used by the XMLRPC fileserver.
    def file_directory
        subpath("files")
    end

    # Return the list of manifests matching the given glob pattern,
    # defaulting to 'init.pp' for empty modules.
    def match_manifests(rest)
        return find_init_manifest unless rest # Use init.pp

        rest ||= "init.pp"
        p = File::join(path, MANIFESTS, rest)
        result = Dir.glob(p).reject { |f| FileTest.directory?(f) }
        if result.size == 0 and rest !~ /\.pp$/
            result = Dir.glob(p + ".pp")
        end
        result.flatten.compact
    end

    # Find this module in the modulepath.
    def path
        environment.modulepath.collect { |path| File.join(path, name) }.find { |d| FileTest.exist?(d) }
    end

    # Find all plugin directories.  This is used by the Plugins fileserving mount.
    def plugin_directory
        subpath("plugins")
    end

    private

    def find_init_manifest
        return [] unless file = manifest("init.pp")
        return [file]
    end

    def subpath(type)
        return File.join(path, type) unless type.to_s == "plugins"

        return backward_compatible_plugins_dir
    end

    def backward_compatible_plugins_dir
        if dir = File.join(path, "plugins") and FileTest.exist?(dir)
            Puppet.warning "Module %s uses the deprecated 'plugins' directory for ruby extensions; please move to 'lib'" % name
            return dir
        else
            return File.join(path, "lib")
        end
    end
end
