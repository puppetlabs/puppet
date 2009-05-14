# Model the environment that a node can operate in.  This class just
# provides a simple wrapper for the functionality around environments.
class Puppet::Node::Environment
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

    def modulepath
        dirs = self[:modulepath].split(File::PATH_SEPARATOR)
        if ENV["PUPPETLIB"]
            dirs = ENV["PUPPETLIB"].split(File::PATH_SEPARATOR) + dirs
        end
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

    # Return all modules from this environment.
    def modules
        result = []
        Puppet::Module.each_module(modulepath) do |mod|
            result << mod
        end
        result
    end

    def to_s
        name.to_s
    end
end
