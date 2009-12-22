require 'puppet/util/cacher'

# Just define it, so this class has fewer load dependencies.
class Puppet::Node
end

# Model the environment that a node can operate in.  This class just
# provides a simple wrapper for the functionality around environments.
class Puppet::Node::Environment
    include Puppet::Util::Cacher

    @seen = {}

    # Return an existing environment instance, or create a new one.
    def self.new(name = nil)
        name ||= Puppet.settings.value(:environment)

        raise ArgumentError, "Environment name must be specified" unless name

        symbol = name.to_sym

        return @seen[symbol] if @seen[symbol]

        obj = self.allocate
        obj.send :initialize, symbol
        @seen[symbol] = obj
    end

    # This is only used for testing.
    def self.clear
        @seen.clear
    end

    attr_reader :name

    # Return an environment-specific setting.
    def [](param)
        Puppet.settings.value(param, self.name)
    end

    def initialize(name)
        @name = name
    end

    def module(name)
        mod = Puppet::Module.new(name, self)
        return nil unless mod.exist?
        return mod
    end

    # Cache the modulepath, so that we aren't searching through
    # all known directories all the time.
    cached_attr(:modulepath, :ttl => Puppet[:filetimeout]) do
        dirs = self[:modulepath].split(File::PATH_SEPARATOR)
        if ENV["PUPPETLIB"]
            dirs = ENV["PUPPETLIB"].split(File::PATH_SEPARATOR) + dirs
        end
        validate_dirs(dirs)
    end

    # Return all modules from this environment.
    # Cache the list, because it can be expensive to create.
    cached_attr(:modules, :ttl => Puppet[:filetimeout]) do
        module_names = modulepath.collect { |path| Dir.entries(path) }.flatten.uniq
        module_names.collect { |path| Puppet::Module.new(path, self) rescue nil }.compact
    end

    # Cache the manifestdir, so that we aren't searching through
    # all known directories all the time.
    cached_attr(:manifestdir, :ttl => Puppet[:filetimeout]) do
        validate_dirs(self[:manifestdir].split(File::PATH_SEPARATOR))
    end

    def to_s
        name.to_s
    end

    def validate_dirs(dirs)
        dirs.collect do |dir|
            if dir !~ /^#{File::SEPARATOR}/
                File.join(Dir.getwd, dir)
            else
                dir
            end
        end.find_all do |p|
            p =~ /^#{File::SEPARATOR}/ && FileTest.directory?(p)
        end
    end

end
