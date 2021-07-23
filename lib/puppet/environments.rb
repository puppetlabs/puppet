require 'puppet/concurrent/synchronized'

# @api private
module Puppet::Environments

  class EnvironmentNotFound < Puppet::Error
    def initialize(environment_name, original = nil)
      environmentpath = Puppet[:environmentpath]
      super("Could not find a directory environment named '#{environment_name}' anywhere in the path: #{environmentpath}. Does the directory exist?", original)
    end
  end

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

  # Provide any common methods that loaders should have. It requires that any
  # classes that include this module implement get
  # @api private
  module EnvironmentLoader
    # @!macro loader_get_or_fail
    def get!(name)
      environment = get(name)
      if environment
        environment
      else
        raise EnvironmentNotFound, name
      end
    end

    def clear_all
      root = Puppet.lookup(:root_environment) { nil }
      unless root.nil?
        root.instance_variable_set(:@static_catalogs, nil)
        root.instance_variable_set(:@rich_data, nil)
      end
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
  #
  # @!macro [new] loader_get_or_fail
  #   Find a named environment or raise
  #   Puppet::Environments::EnvironmentNotFound when the named environment is
  #   does not exist.
  #
  #   @param name [String,Symbol] The name of environment to find
  #   @return [Puppet::Node::Environment] the requested environment

  # A source of pre-defined environments.
  #
  # @api private
  class Static
    include EnvironmentCreator
    include EnvironmentLoader

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
        Puppet::Settings::EnvironmentConf.static_for(env, Puppet[:environment_timeout], Puppet[:static_catalogs], Puppet[:rich_data])
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

  class StaticDirectory < Static
    # Accepts a single environment in the given directory having the given name (not required to be reflected as the name
    # of the directory)
    def initialize(env_name, env_dir, environment)
      super(environment)
      @env_dir = env_dir
      @env_name = env_name.intern
    end

    # @!macro loader_get_conf
    def get_conf(name)
      return nil unless name.intern == @env_name
      Puppet::Settings::EnvironmentConf.load_from(@env_dir, [])
    end
  end

  # Reads environments from a directory on disk. Each environment is
  # represented as a sub-directory. The environment's manifest setting is the
  # `manifest` directory of the environment directory. The environment's
  # modulepath setting is the global modulepath (from the `[server]` section
  # for the server) prepended with the `modules` directory of the environment
  # directory.
  #
  # @api private
  class Directories
    include EnvironmentLoader

    def initialize(environment_dir, global_module_path)
      @environment_dir =  Puppet::FileSystem.expand_path(environment_dir)
      @global_module_path = global_module_path ?
        global_module_path.map { |p| Puppet::FileSystem.expand_path(p) } :
        nil
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

    def self.real_path(dir)
      if Puppet::FileSystem.symlink?(dir) && Puppet[:versioned_environment_dirs]
        dir = Pathname.new Puppet::FileSystem.expand_path(Puppet::FileSystem.readlink(dir))
      end
      return dir
    end

    # @!macro loader_search_paths
    def search_paths
      ["file://#{@environment_dir}"]
    end

    # @!macro loader_list
    def list
      valid_environment_names.collect do |name|
        create_environment(name)
      end
    end

    # @!macro loader_get
    def get(name)
      if validated_directory(File.join(@environment_dir, name.to_s))
        create_environment(name)
      end
    end

    # @!macro loader_get_conf
    def get_conf(name)
      envdir = validated_directory(File.join(@environment_dir, name.to_s))
      if envdir
        Puppet::Settings::EnvironmentConf.load_from(envdir, @global_module_path)
      else
        nil
      end
    end

    private

    def create_environment(name)
      # interpolated modulepaths may be cached from prior environment instances
      Puppet.settings.clear_environment_settings(name)

      env_symbol = name.intern
      setting_values = Puppet.settings.values(env_symbol, Puppet.settings.preferred_run_mode)
      env = Puppet::Node::Environment.create(
        env_symbol,
        Puppet::Node::Environment.split_path(setting_values.interpolate(:modulepath)),
        setting_values.interpolate(:manifest),
        setting_values.interpolate(:config_version)
      )
      env
    end

    def validated_directory(envdir)
      env_name = Puppet::FileSystem.basename_string(envdir)
      envdir = Puppet::Environments::Directories.real_path(envdir).to_s
      if Puppet::FileSystem.directory?(envdir) && Puppet::Node::Environment.valid_name?(env_name)
        envdir
      else
        nil
      end
    end

    def valid_environment_names
      return [] unless Puppet::FileSystem.directory?(@environment_dir)
      Puppet::FileSystem.children(@environment_dir).map do |child|
        Puppet::FileSystem.basename_string(child).intern if validated_directory(child)
      end.compact
    end
  end

  # Combine together multiple loaders to act as one.
  # @api private
  class Combined
    include EnvironmentLoader

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
        env = loader.get(name)
        if env
          return env
        end
      end
      nil
    end

    # @!macro loader_get_conf
    def get_conf(name)
      @loaders.each do |loader|
        conf = loader.get_conf(name)
        if conf
          return conf
        end
      end
      nil
    end

    def clear_all
      @loaders.each {|loader| loader.clear_all}
    end
  end

  class Cached
    include EnvironmentLoader
    include Puppet::Concurrent::Synchronized

    class DefaultCacheExpirationService
      # Called when the environment is created.
      #
      # @param [Puppet::Node::Environment] env
      def created(env)
      end

      # Is the environment with this name expired?
      #
      # @param [Symbol] env_name The symbolic environment name
      # @return [Boolean]
      def expired?(env_name)
        false
      end

      # The environment with this name was evicted.
      #
      # @param [Symbol] env_name The symbolic environment name
      def evicted(env_name)
      end
    end

    def self.cache_expiration_service=(service)
      @cache_expiration_service = service
    end

    def self.cache_expiration_service
      @cache_expiration_service || DefaultCacheExpirationService.new
    end

    # Returns the end of time (the next Mesoamerican Long Count cycle-end after 2012 (5125+2012) = 7137
    def self.end_of_time
      Time.gm(7137)
    end

    END_OF_TIME = end_of_time
    START_OF_TIME = Time.gm(1)

    def initialize(loader)
      @loader = loader
      @cache_expiration_service = Puppet::Environments::Cached.cache_expiration_service
      @cache = {}
    end

    # @!macro loader_list
    def list
      # Evict all that have expired, in the same way as `get`
      clear_all_expired

      # Evict all that was removed from diks
      cached_envs = @cache.keys.map!(&:to_sym)
      loader_envs = @loader.list.map!(&:name)
      removed_envs = cached_envs - loader_envs

      removed_envs.each do |env_name|
        Puppet.debug { "Environment no longer exists '#{env_name}'"}
        clear(env_name)
      end

      @loader.list.map do |env|
        name = env.name
        old_entry = @cache[name]
        if old_entry
          old_entry.value
        else
          add_entry(name, entry(env))
          env
        end
      end
    end

    # @!macro loader_search_paths
    def search_paths
      @loader.search_paths
    end

    # @!macro loader_get
    def get(name)
      # Aggressively evict all that has expired
      # This strategy favors smaller memory footprint over environment
      # retrieval time.
      clear_all_expired
      result = @cache[name]
      if result
        Puppet.debug {"Found in cache '#{name}' #{result.label}"}
        # found in cache
        result.touch
        return result.value
      elsif (result = @loader.get(name))
        # environment loaded, cache it
        cache_entry = entry(result)
        add_entry(name, cache_entry)
        result
      end
    end

    # Adds a cache entry to the cache
    def add_entry(name, cache_entry)
      Puppet.debug {"Caching environment '#{name}' #{cache_entry.label}"}
      @cache[name] = cache_entry
      @cache_expiration_service.created(cache_entry.value)
    end
    private :add_entry

    def clear_entry(name, entry)
      @cache.delete(name)
      Puppet.debug {"Evicting cache entry for environment '#{name}'"}
      @cache_expiration_service.evicted(name.to_sym)
      Puppet::GettextConfig.delete_text_domain(name)
      Puppet.settings.clear_environment_settings(name)
    end
    private :clear_entry

    # Clears the cache of the environment with the given name.
    # (The intention is that this could be used from a MANUAL cache eviction command (TBD)
    def clear(name)
      entry = @cache[name]
      clear_entry(name, entry) if entry
    end

    # Clears all cached environments.
    # (The intention is that this could be used from a MANUAL cache eviction command (TBD)
    def clear_all
      super

      @cache.each_pair do |name, entry|
        clear_entry(name, entry)
      end

      @cache = {}
      Puppet::GettextConfig.delete_environment_text_domains
    end

    # Clears all environments that have expired, either by exceeding their time to live, or
    # through an explicit eviction determined by the cache expiration service.
    #
    def clear_all_expired()
      t = Time.now

      @cache.each_pair do |name, entry|
        clear_if_expired(name, entry, t)
      end
    end

    # Clear an environment if it is expired, either by exceeding its time to live, or
    # through an explicit eviction determined by the cache expiration service.
    #
    def clear_if_expired(name, entry, t = Time.now)
      return unless entry

      if entry.expired?(t) || @cache_expiration_service.expired?(name.to_sym)
        clear_entry(name, entry)
      end
    end
    private :clear_if_expired

    # This implementation evicts the cache, and always gets the current
    # configuration of the environment
    #
    # TODO: While this is wasteful since it
    # needs to go on a search for the conf, it is too disruptive to optimize
    # this.
    #
    # @!macro loader_get_conf
    def get_conf(name)
      clear_if_expired(name, @cache[name])
      @loader.get_conf(name)
    end

    # Creates a suitable cache entry given the time to live for one environment
    #
    def entry(env)
      ttl = if (conf = get_conf(env.name))
              conf.environment_timeout
            else
              Puppet[:environment_timeout]
            end

      case ttl
      when 0
        NotCachedEntry.new(env)     # Entry that is always expired (avoids syscall to get time)
      when Float::INFINITY
        Entry.new(env)              # Entry that never expires (avoids syscall to get time)
      else
        if Puppet[:environment_timeout_mode] == :from_last_used
          MRUEntry.new(env, ttl)    # Entry that expires in ttl from when it was last touched
        else
          TTLEntry.new(env, ttl)    # Entry that expires in ttl from when it was created
        end
      end
    end

    # Never evicting entry
    class Entry
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def touch
      end

      def expired?(now)
        false
      end

      def label
        ""
      end
    end

    # Always evicting entry
    class NotCachedEntry < Entry
      def expired?(now)
        true
      end

      def label
        "(ttl = 0 sec)"
      end
    end

    # Policy that expires in ttl_seconds from when it was created
    class TTLEntry < Entry
      def initialize(value, ttl_seconds)
        super(value)
        @ttl = Time.now + ttl_seconds
        @ttl_seconds = ttl_seconds
      end

      def expired?(now)
        now > @ttl
      end

      def label
        "(ttl = #{@ttl_seconds} sec)"
      end
    end

    # Policy that expires if it hasn't been touched within ttl_seconds
    class MRUEntry < TTLEntry
      def initialize(value, ttl_seconds)
        super(value, ttl_seconds)

        touch
      end

      def touch
        @ttl = Time.now + @ttl_seconds
      end

      def label
        "(mru = #{@ttl_seconds} sec)"
      end
    end
  end
end
