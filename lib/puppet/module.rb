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

                yield Puppet::Module.new(name, module_path)
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
        Puppet::Node::Environment.new(environment).module(modname)
    end

    attr_reader :name, :path
    def initialize(name, path)
        @name = name
        @path = path
    end

    FILETYPES.each do |type|
        # Create a method for returning the full path to a given
        # file type's directory.
        define_method(type.to_s) do
            File.join(path, type.to_s)
        end

        # Create a boolean method for testing whether our module has
        # files of a given type.
        define_method(type.to_s + "?") do
            FileTest.exist?(send(type))
        end

        # Finally, a method for returning an individual file
        define_method(type.to_s.sub(/s$/, '')) do |file|
            if file
                path = File.join(send(type), file)
            else
                path = send(type)
            end
            return nil unless FileTest.exist?(path)
            return path
        end
    end

    # Return the list of manifests matching the given glob pattern,
    # defaulting to 'init.pp' for empty modules.
    def match_manifests(rest)
        rest ||= "init.pp"
        p = File::join(path, MANIFESTS, rest)
        files = Dir.glob(p).reject { |f| FileTest.directory?(f) }
        if files.size == 0
            files = Dir.glob(p + ".pp")
        end
        return files
    end
end
