module Puppet::Environments
  class NotFoundError < Puppet::Error; end

  module EnvironmentCreator
    def for(module_path, manifest)
      Puppet::Node::Environment.create(:anonymous,
                                       module_path.split(File::PATH_SEPARATOR),
                                       manifest)
    end
  end

  class OnlyProduction
    def search_paths
      ["environments://static/production"]
    end

    def list
      [Puppet::Node::Environment.new(:production)]
    end
  end

  class Static
    include EnvironmentCreator

    def initialize(*environments)
      @environments = environments
    end

    def search_paths
      ["environments://static/memory"]
    end

    def list
      @environments
    end

    def get(name)
      @environments.find do |env|
        env.name == name.intern
      end
    end
  end

  class Legacy
    include EnvironmentCreator

    def search_paths
      ["environments://legacy/cached"]
    end

    def list
      []
    end

    def get(name)
      Puppet::Node::Environment.new(name)
      #symbol = name.to_sym
      #Puppet::Node::Environment.create(
      #  symbol,
      #  Puppet::Node::Environment.split_path(Puppet.settings.value(:modulepath, symbol)),
      #  Puppet.settings.value(:manifest, symbol))
    end
  end

  class Directories
    def initialize(environment_dir, global_module_path)
      @environment_dir = environment_dir
      @global_module_path = global_module_path
    end

    def search_paths
      ["environments://directories/#{@environment_dir}"]
    end

    def list
      base = Puppet::FileSystem.path_string(@environment_dir)

      Puppet::FileSystem.children(@environment_dir).select do |child|
        name = Puppet::FileSystem.basename_string(child)
        Puppet::FileSystem.directory?(child) &&
           Puppet::Node::Environment.valid_name?(name)
      end.collect do |child|
        name = Puppet::FileSystem.basename_string(child)
        Puppet::Node::Environment.create(
          name.intern,
          [File.join(base, name, "modules")] + @global_module_path,
          File.join(base, name, "manifests"))
      end
    end

    def get(name)
      list.find { |env| env.name == name.intern }
    end
  end

  class Combined
    def initialize(*loaders)
      @loaders = loaders
    end

    def search_paths
      @loaders.collect(&:search_paths).flatten
    end

    def list
      @loaders.collect(&:list).flatten
    end

    def get(name)
      @loaders.each do |loader|
        if env = loader.get(name)
          return env
        end
      end
      nil
    end
  end
end
