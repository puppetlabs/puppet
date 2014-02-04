# @api private
module Puppet::Environments
  # @api private
  module EnvironmentCreator
    # Create an anonymous environment.
    #
    # @param module_path [String] A list of module directories separated by the
    #   PATH_SEPARATOR
    # @param manifest [String] The path to the manifest
    # @return A new environment with the `name` `:anonymous`
    #
    # @api private
    def for(module_path, manifest)
      Puppet::Node::Environment.create(:anonymous,
                                       module_path.split(File::PATH_SEPARATOR),
                                       manifest)
    end
  end

  # @!macro [new] loader_search_paths
  #   A list of indicators of where the loader is getting its environments from.
  #   @return [Array<String>] The URIs of the load locations
  #
  # @!macro [new] loader_list
  #   @return [Array<Puppet::Node::Environment>] All of the environments known
  #     to the loader
  #
  # @!macro [new] loader_get
  #   Find a named environment
  #
  #   @param name [String,Symbol] The name of environment to find
  #   @return [Puppet::Node::Environment, nil] the requested environment or nil
  #     if it wasn't found

  # A source of pre-defined environments.
  #
  # @api private
  class Static
    include EnvironmentCreator

    def initialize(*environments)
      @environments = environments
    end

    # @!macro loader_search_paths
    def search_paths
      ["environments://static/memory"]
    end

    # @!macro loader_list
    def list
      @environments
    end

    # @!macro loader_get
    def get(name)
      @environments.find do |env|
        env.name == name.intern
      end
    end
  end

  # Old-style environments that come either from explicit stanzas in
  # puppet.conf or from dynamic environments created from use of `$environment`
  # in puppet.conf.
  #
  # @example Explicit Stanza
  #   [environment_name]
  #   modulepath=/var/my_env/modules
  #
  # @example Dynamic Environments
  #   [master]
  #   modulepath=/var/$environment/modules
  #
  # @api private
  class Legacy
    include EnvironmentCreator

    # @!macro loader_search_paths
    def search_paths
      ["environments://legacy"]
    end

    # @note The list of environments for the Legacy environments is always
    #   empty.
    #
    # @!macro loader_list
    def list
      []
    end

    # @note Because the Legacy system cannot list out all of its environments,
    #   get is able to return environments that are not returned by a call to
    #   {#list}.
    #
    # @!macro loader_get
    def get(name)
      Puppet::Node::Environment.new(name)
    end
  end

  # Reads environments from a directory on disk. Each environment is
  # represented as a sub-directory. The environment's manifest setting is the
  # `manifest` directory of the environment directory. The environment's
  # modulepath setting is the global modulepath (from the `[master]` section
  # for the master) prepended with the `modules` directory of the environment
  # directory.
  #
  # @api private
  class Directories
    def initialize(environment_dir, global_module_path)
      @environment_dir = environment_dir
      @global_module_path = global_module_path
    end

    # Generate an array of directory loaders from a path string.
    # @param path [String] path to environment directories
    # @param global_module_path [String] the global modulepath setting
    # @return [Array<Puppet::Environments::Directories>] An array
    #   of configured directory loaders.
    def self.from_path(path, global_module_path)
      environments = path.split(File::PATH_SEPARATOR)
      environments.map do |dir|
        Puppet::Environments::Directories.new(dir, global_module_path)
      end
    end

    # @!macro loader_search_paths
    def search_paths
      ["environments://directories/#{@environment_dir}"]
    end

    # @!macro loader_list
    def list
      base = Puppet::FileSystem.path_string(@environment_dir)

      if Puppet::FileSystem.directory?(@environment_dir)
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
      else
        []
      end
    end

    # @!macro loader_get
    def get(name)
      list.find { |env| env.name == name.intern }
    end
  end

  # Combine together multiple loaders to act as one.
  # @api private
  class Combined
    def initialize(*loaders)
      @loaders = loaders
    end

    # @!macro loader_search_paths
    def search_paths
      @loaders.collect(&:search_paths).flatten
    end

    # @!macro loader_list
    def list
      @loaders.collect(&:list).flatten
    end

    # @!macro loader_get
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
