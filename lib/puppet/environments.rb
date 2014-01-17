module Puppet::Environments
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
