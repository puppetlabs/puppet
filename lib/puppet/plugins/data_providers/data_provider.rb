require 'puppet/pops/lookup/interpolation'

# TODO: API 5.0, remove this module
# @api private
# @deprecated
module Puppet::Plugins::DataProviders
  # @deprecated
  module DataProvider
    include Puppet::Pops::Lookup::DataProvider
    include Puppet::Pops::Lookup::Interpolation

    def key_lookup(key, lookup_invocation, merge)
      lookup(key.to_s, lookup_invocation, merge)
    end

    def unchecked_key_lookup(key, lookup_invocation, merge)
      unchecked_lookup(key.to_s, lookup_invocation, merge)
    end

    # @deprecated
    def lookup(key, lookup_invocation, merge)
      lookup_invocation.check(key) { unchecked_lookup(key, lookup_invocation, merge) }
    end

    # Performs a lookup with the assumption that a recursive check has been made.
    #
    # @param key [String] The key to lookup
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [String|Hash{String => Object}] Merge strategy or hash with strategy and options
    def unchecked_lookup(key, lookup_invocation, merge)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'DataProvider#unchecked_lookup',
          'DataProvider#unchecked_lookup is deprecated and will be removed in the next major version of Puppet')
      end
      segments = split_key(key)
      root_key = segments.shift
      lookup_invocation.with(:data_provider, self) do
        hash = data(data_key(root_key, lookup_invocation), lookup_invocation)
        value = hash[root_key]
        if value || hash.include?(root_key)
          value = sub_lookup(key, lookup_invocation, segments, value) unless segments.empty?
          lookup_invocation.report_found(key, post_process(value, lookup_invocation))
        else
          lookup_invocation.report_not_found(key)
          throw :no_such_key
        end
      end
    end

    # Perform optional post processing of found value. The default implementation resolves
    # interpolation expressions
    #
    # @param value [Object] The value to perform post processing on
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Object] The result of post processing the value.
    # @deprecated
    def post_process(value, lookup_invocation)
      interpolate(value, lookup_invocation, true)
    end

    # Gets the data from the compiler, or initializes it by calling #initialize_data if not present in the compiler.
    # This means, that data is initialized once per compilation, and the data is cached for as long as the compiler
    # lives (which is for one catalog production). This makes it possible to return data that is tailored for the
    # request.
    #
    # If data is obtained using the #initialize_data method it will be sent to the #validate_data for validation
    #
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
    # @return [Hash] The data hash for the given _key_
    # @deprecated
    def data(data_key, lookup_invocation)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'DataProvider#data',
          'DataProvider#data is deprecated and will be removed in the next major version of Puppet')
      end
      compiler = lookup_invocation.scope.compiler
      adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
      adapter.data[data_key] ||= validate_data(initialize_data(data_key, lookup_invocation))
    end
    protected :data

    # Obtain an optional key to use when retrieving the data.
    #
    # @param key [String] The key to lookup
    # @return [String,nil] The data key or nil if not applicable
    # @deprecated
    def data_key(key, lookup_invocation)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'DataProvider#data_key',
          'DataProvider#data_key is deprecated and will be removed in the next major version of Puppet')
      end
      nil
    end

    # Should be reimplemented by subclass to provide the hash that corresponds to the given name.
    #
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Hash] The hash of values
    # @deprecated
    def initialize_data(data_key, lookup_invocation)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'DataProvider#initialize_data',
          'DataProvider#initialize_data is deprecated and will be removed in the next major version of Puppet')
      end
      {}
    end
    protected :initialize_data

    def name
      cname = self.class.name
      cname[cname.rindex(':')+1..-1]
    end

    # @deprecated
    def validate_data(data, data_key)
      data
    end
  end

  # TODO: API 5.0 Remove this class
  # @deprecated
  # @api private
  class ModuleDataProvider
    LOOKUP_OPTIONS = 'lookup_options'.freeze
    include DataProvider

    attr_reader :module_name

    def initialize(module_name = nil)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'Plugins::DataProviders::ModuleDataProvider',
          'Plugins::DataProviders::ModuleDataProvider is deprecated and will be removed in the next major version of Puppet')
      end
      @module_name = module_name || Puppet::Pops::Lookup::Invocation.current.module_name
    end

    # Retrieve the first segment of the qualified name _key_. This method will throw
    # :no_such_key unless the segment can be extracted.
    #
    # @param key [String] The key
    # @return [String] The first segment of the given key
    # @api private
    # @deprecated
    def data_key(key, lookup_invocation)
      return module_name if key == LOOKUP_OPTIONS
      qual_index = key.index('::')
      throw :no_such_key if qual_index.nil?
      key[0..qual_index-1]
    end

    # Asserts that all keys in the given _data_ are prefixed with the given _module_name_. Remove entries
    # that does not follow the convention and log a warning.
    #
    # @param data [Hash] The data hash
    # @param module_name [String] The name of the module where the data was found
    # @return [Hash] The possibly pruned hash
    # @api public
    def validate_data(data, module_name)
      module_prefix = "#{module_name}::"
      data.each_key.reduce(data) do |memo, k|
        if k.is_a?(String)
          next memo if k == LOOKUP_OPTIONS || k.start_with?(module_prefix)
          msg = 'must use keys qualified with the name of the module'
        else
          msg = "must use keys of type String, got #{k.class.name}"
        end
        memo = memo.clone if memo.equal?(data)
        memo.delete(k)
        Puppet.warning("Module data for module '#{module_name}' #{msg}")
        memo
      end
    end
  end

  # TODO: API 5.0 Remove this class
  # @deprecated
  # @api private
  class EnvironmentDataProvider
    include DataProvider

    def initialize
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'Plugins::DataProviders::EnvironmentDataProvider',
          'Plugins::DataProviders::EnvironmentDataProvider is deprecated and will be removed in the next major version of Puppet')
      end
    end

    # @api private
    # @deprecated
    def data_key(key, lookup_invocation)
      'environment'
    end
  end

  # Class that keeps track of the original path (as it appears in the declaration, before interpolation),
  # the fully resolved path, and whether or the resolved path exists.
  #
  # @api private
  # @deprecated
  class ResolvedPath
    attr_reader :original_path, :path

    # @param original_path [String] path as found in declaration. May contain interpolation expressions
    # @param path [Pathname] the expanded absolute path
    # @deprecated
    def initialize(original_path, path)
      @original_path = original_path
      @path = path
      @exists = nil
    end

    # @return [Boolean] cached info if the path exists or not
    # @deprecated
    def exists?
      @exists = @path.exist? if @exists.nil?
      @exists
    end
    alias exist? exists?
  end

  # A data provider that is initialized with a set of _paths_. When performing lookup, each
  # path is search in the order they appear. If a value is found in more than one location it
  # will be merged according to a given (optional) merge strategy.
  #
  # @abstract
  # @api private
  # @deprecated
  class PathBasedDataProvider
    include DataProvider

    attr_reader :name

    # @param name [String] The name of the data provider
    # @param paths [Array<ResolvedPath>] Paths used by this provider
    # @param parent_data_provider [DataProvider] The data provider that is the container of this data provider
    # @deprecated
    def initialize(name, paths, parent_data_provider = nil)
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'PathBasedDataProvider',
          'PathBasedDataProvider is deprecated and will be removed in the next major version of Puppet')
      end
      @name = name
      @paths = paths
      @parent_data_provider = parent_data_provider
    end

    # Gets the data from the compiler, or initializes it by calling #initialize_data if not present in the compiler.
    # This means, that data is initialized once per compilation, and the data is cached for as long as the compiler
    # lives (which is for one catalog production). This makes it possible to return data that is tailored for the
    # request.
    #
    # If data is obtained using the #initialize_data method it will be sent to the #validate_data for validation
    #
    # @param path [String] The path to the data to be loaded (passed to #initialize_data)
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
    # @return [Hash] The data hash for the given _key_
    # @deprecated
    def load_data(path, data_key, lookup_invocation)
      compiler = lookup_invocation.scope.compiler
      adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
      adapter.data[path] ||= validate_data(initialize_data(path, lookup_invocation), data_key)
    end
    protected :data

    # @deprecated
    def validate_data(data, module_name)
      @parent_data_provider.nil? ? data : @parent_data_provider.validate_data(data, module_name)
    end

    # Performs a lookup by searching all given paths for the given _key_. A merge will be performed if
    # the value is found in more than one location and _merge_ is not nil.
    #
    # @param key [String] The key to lookup
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [Puppet::Pops::MergeStrategy,String,Hash<String,Object>,nil] Merge strategy or hash with strategy and options
    # @deprecated
    def unchecked_lookup(key, lookup_invocation, merge)
      segments = split_key(key)
      root_key = segments.shift

      module_name = @parent_data_provider.nil? ? nil : @parent_data_provider.data_key(key, lookup_invocation)
      lookup_invocation.with(:data_provider, self) do
        merge_strategy = Puppet::Pops::MergeStrategy.strategy(merge)
        lookup_invocation.with(:merge, merge_strategy) do
          merged_result = merge_strategy.merge_lookup(@paths) do |path|
            lookup_invocation.with(:location, path) do
              if path.exists?
                hash = load_data(path.path, module_name, lookup_invocation)
                value = hash[root_key]
                if value || hash.include?(root_key)
                  value = sub_lookup(key, lookup_invocation, segments, value) unless segments.empty?
                  lookup_invocation.report_found(key, post_process(value, lookup_invocation))
                else
                  lookup_invocation.report_not_found(key)
                  throw :no_such_key
                end
              else
                lookup_invocation.report_location_not_found
                throw :no_such_key
              end
            end
          end
          lookup_invocation.report_result(merged_result)
        end
      end
    end
  end

  # TODO: API 5.0 Remove this class
  # Factory for creating path based data providers
  #
  # @abstract
  # @api private
  # @deprecated
  class PathBasedDataProviderFactory
    # @deprecated
    def initialize
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'PathBasedDataProviderFactory',
        'PathBasedDataProviderFactory is deprecated and will be removed in the next major version of Puppet')
      end
    end

    # Create a path based data provider with the given _name_ and _paths_
    #
    # @param name [String] the name of the created provider (for logging and debugging)
    # @param paths [Array<String>] array of resolved paths
    # @param parent_data_provider [DataProvider] The data provider that is the container of this data provider
    # @return [DataProvider] The created data provider
    # @deprecated
    def create(name, paths, parent_data_provider)
      raise NotImplementedError, "Subclass of PathBasedDataProviderFactory must implement 'create' method"
    end

    # Resolve the given _paths_ to something that is meaningful as a _paths_ argument when creating
    # a provider using the #create call.
    #
    # In order to increase efficiency, the implementors of this method should ensure that resolved
    # paths that exists are included in the result.
    #
    # @param datadir [Pathname] The base when creating absolute paths
    # @param declared_paths [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param paths [Array<String>] paths that have been preprocessed (interpolations resolved)
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Array<ResolvedPath>] Array of resolved paths
    # @deprecated
    def resolve_paths(datadir, declared_paths, paths, lookup_invocation)
      []
    end

    # Returns the data provider factory version.
    #
    # return [Integer] the version of this data provider factory
    def version
      2
    end
  end

  # TODO: API 5.0 Remove this class
  # Factory for creating file based data providers. This is an extension of the path based
  # factory where it is required that each resolved path appoints an existing file in the local
  # file system.
  #
  # @abstract
  # @api private
  # @deprecated
  class FileBasedDataProviderFactory < PathBasedDataProviderFactory
    # @deprecated
    def initialize
      unless Puppet[:strict] == :off
        Puppet.warn_once(:deprecation, 'FileBasedDataProviderFactory',
          'FileBasedDataProviderFactory is deprecated and will be removed in the next major version of Puppet')
      end
    end

    # @param datadir [Pathname] The base when creating absolute paths
    # @param declared_paths [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param paths [Array<String>] paths that have been preprocessed (interpolations resolved)
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Array<Puppet::DataProviders::ResolvedLocation>] Array of resolved paths
    # @deprecated
    def resolve_paths(datadir, declared_paths, paths, lookup_invocation)
      resolved_paths = []
      unless paths.nil? || datadir.nil?
        ext = path_extension
        paths.each_with_index do |path, idx|
          path = path + ext unless path.end_with?(ext)
          path = datadir + path
          resolved_paths << Puppet::Pops::Lookup::ResolvedLocation.new(declared_paths[idx], path, path.exist?)
        end
      end
      resolved_paths
    end

    # @deprecated
    def path_extension
      raise NotImplementedError, "Subclass of FileBasedProviderFactory must implement 'path_extension' method"
    end
    protected :path_extension
  end
end
