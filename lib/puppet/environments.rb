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
  #
  # @!macro [new] loader_get_conf
  #   Attempt to obtain the initial configuration for the environment.  Not all
  #   loaders can provide this.
  #
  #   @param name [String,Symbol] The name of the environment whose configuration
  #     we are looking up
  #   @return [Puppet::Setting::EnvironmentConf, nil] the configuration for the
  #     requested environment, or nil if not found or no configuration is available

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
      ["data:text/plain,internal"]
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

    # Returns a basic environment configuration object tied to the environment's
    # implementation values.  Will not interpolate.
    #
    # @!macro loader_get_conf
    def get_conf(name)
      env = get(name)
      if env
        Puppet::Settings::EnvironmentConf.static_for(env)
      else
        nil
      end
    end
  end

  # A source of unlisted pre-defined environments.
  #
  # Used only for internal bootstrapping environments which are not relevant
  # to an end user (such as the fall back 'configured' environment).
  #
  # @api private
  class StaticPrivate < Static

    # Unlisted
    #
    # @!macro loader_list
    def list
      []
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
      ["file://#{Puppet[:config]}"]
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

    # @note we could return something here, but since legacy environments
    #   are deprecated, there is no point.
    #
    # @!macro loader_get_conf
    def get_conf(name)
      nil
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
    # @param global_module_path [Array<String>] the global modulepath setting
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
      ["file://#{@environment_dir}"]
    end

    # @!macro loader_list
    def list
      valid_directories.collect do |envdir|
        name = Puppet::FileSystem.basename_string(envdir)

        setting_values = Puppet.settings.values(name, Puppet.settings.preferred_run_mode)
        Puppet::Node::Environment.create(
          name.intern,
          Puppet::Node::Environment.split_path(setting_values.interpolate(:modulepath)),
          setting_values.interpolate(:manifest),
          setting_values.interpolate(:config_version)
        )
      end
    end

    # @!macro loader_get
    def get(name)
      list.find { |env| env.name == name.intern }
    end

    # @!macro loader_get_conf
    def get_conf(name)
      valid_directories.each do |envdir|
        envname = Puppet::FileSystem.basename_string(envdir)
        if envname == name.to_s
          return Puppet::Settings::EnvironmentConf.load_from(envdir, @global_module_path)
        end
      end
      nil
    end

    private

    def valid_directories
      if Puppet::FileSystem.directory?(@environment_dir)
        Puppet::FileSystem.children(@environment_dir).select do |child|
          name = Puppet::FileSystem.basename_string(child)
          Puppet::FileSystem.directory?(child) &&
             Puppet::Node::Environment.valid_name?(name)
        end
      else
        []
      end
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

    # @!macro loader_get_conf
    def get_conf(name)
      @loaders.each do |loader|
        if conf = loader.get_conf(name)
          return conf
        end
      end
      nil
    end
  end
end
