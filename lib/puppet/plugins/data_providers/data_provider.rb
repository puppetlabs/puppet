require 'puppet/pops/lookup/interpolation'

module Puppet::Plugins::DataProviders
  module DataProvider
    include Puppet::Pops::Lookup::Interpolation

    # Performs a lookup with an endless recursion check.
    #
    # @param key [String] The key to lookup
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
    #
    # @api public
    def lookup(name, lookup_invocation, merge)
      lookup_invocation.check(name) { unchecked_lookup(name, lookup_invocation, merge) }
    end

    # Performs a lookup with the assumption that a recursive check has been made.
    #
    # @param key [String] The key to lookup
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
    #
    # @api public
    def unchecked_lookup(key, lookup_invocation, merge)
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
    #
    # @api public
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
    #
    # @api public
    def data(data_key, lookup_invocation)
      compiler = lookup_invocation.scope.compiler
      adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
      adapter.data[data_key] ||= validate_data(initialize_data(data_key, lookup_invocation), data_key)
    end
    protected :data

    # Obtain an optional key to use when retrieving the data.
    #
    # @param key [String] The key to lookup
    # @return [String,nil] The data key or nil if not applicable
    #
    # @api public
    def data_key(key, lookup_invocation)
      nil
    end

    # Should be reimplemented by subclass to provide the hash that corresponds to the given name.
    #
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Hash] The hash of values
    #
    # @api public
    def initialize_data(data_key, lookup_invocation)
      {}
    end
    protected :initialize_data

    def name
      cname = self.class.name
      cname[cname.rindex(':')+1..-1]
    end

    def validate_data(data, data_key)
      data
    end
  end

  class ModuleDataProvider
    LOOKUP_OPTIONS = Puppet::Pops::Lookup::LOOKUP_OPTIONS
    include DataProvider

    # Retrieve the first segment of the qualified name _key_. This method will throw
    # :no_such_key unless the segment can be extracted.
    #
    # @param key [String] The key
    # @return [String] The first segment of the given key
    def data_key(key, lookup_invocation)
      return lookup_invocation.module_name if key == LOOKUP_OPTIONS
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

  class EnvironmentDataProvider
    include DataProvider

    def data_key(key, lookup_invocation)
      'environment'
    end
  end

  # Class that keeps track of the original path (as it appears in the declaration, before interpolation),
  # the fully resolved path, and whether or the resolved path exists.
  #
  # @api public
  class ResolvedPath
    attr_reader :original_path, :path

    # @param original_path [String] path as found in declaration. May contain interpolation expressions
    # @param path [Pathname] the expanded absolute path
    # @api public
    def initialize(original_path, path)
      @original_path = original_path
      @path = path
      @exists = nil
    end

    # @return [Boolean] cached info if the path exists or not
    # @api public
    def exists?
      @exists = @path.exist? if @exists.nil?
      @exists
    end
  end

  # A data provider that is initialized with a set of _paths_. When performing lookup, each
  # path is search in the order they appear. If a value is found in more than one location it
  # will be merged according to a given (optional) merge strategy.
  #
  # @abstract
  # @api public
  class PathBasedDataProvider
    include DataProvider

    attr_reader :name

    # @param name [String] The name of the data provider
    # @param paths [Array<ResolvedPath>] Paths used by this provider
    # @param parent_data_provider [DataProvider] The data provider that is the container of this data provider
    #
    # @api public
    def initialize(name, paths, parent_data_provider = nil)
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
    #
    # @api public
    def load_data(path, data_key, lookup_invocation)
      compiler = lookup_invocation.scope.compiler
      adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
      adapter.data[path] ||= validate_data(initialize_data(path, lookup_invocation), data_key)
    end
    protected :data

    def validate_data(data, module_name)
      @parent_data_provider.nil? ? data : @parent_data_provider.validate_data(data, module_name)
    end

    # Performs a lookup by searching all given paths for the given _key_. A merge will be performed if
    # the value is found in more than one location and _merge_ is not nil.
    #
    # @param key [String] The key to lookup
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @param merge [Puppet::Pops::MergeStrategy,String,Hash<String,Object>,nil] Merge strategy or hash with strategy and options
    #
    # @api public
    def unchecked_lookup(key, lookup_invocation, merge)
      segments = split_key(key)
      root_key = segments.shift

      module_name = @parent_data_provider.nil? ? nil : @parent_data_provider.data_key(key, lookup_invocation)
      lookup_invocation.with(:data_provider, self) do
        merge_strategy = Puppet::Pops::MergeStrategy.strategy(merge)
        lookup_invocation.with(:merge, merge_strategy) do
          merged_result = merge_strategy.merge_lookup(@paths) do |path|
            lookup_invocation.with(:path, path) do
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
                lookup_invocation.report_path_not_found
                throw :no_such_key
              end
            end
          end
          lookup_invocation.report_result(merged_result)
        end
      end
    end
  end

  # Factory for creating path based data providers
  #
  # @abstract
  # @api public
  class PathBasedDataProviderFactory
    # Create a path based data provider with the given _name_ and _paths_
    #
    # @param name [String] the name of the created provider (for logging and debugging)
    # @param paths [Array<String>] array of resolved paths
    # @param parent_data_provider [DataProvider] The data provider that is the container of this data provider
    # @return [DataProvider] The created data provider
    #
    # @api public
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
    #
    # @api public
    def resolve_paths(datadir, declared_paths, paths, lookup_invocation)
      []
    end

    # Returns the data provider factory version.
    #
    # return [Integer] the version of this data provider factory
    # @api public
    def version
      2
    end
  end

  # Factory for creating file based data providers. This is an extension of the path based
  # factory where it is required that each resolved path appoints an existing file in the local
  # file system.
  #
  # @abstract
  # @api public
  class FileBasedDataProviderFactory < PathBasedDataProviderFactory
    # @param datadir [Pathname] The base when creating absolute paths
    # @param declared_paths [Array<String>] paths as found in declaration. May contain interpolation expressions
    # @param paths [Array<String>] paths that have been preprocessed (interpolations resolved)
    # @param lookup_invocation [Puppet::Pops::Lookup::Invocation] The current lookup invocation
    # @return [Array<ResolvedPath>] Array of resolved paths
    def resolve_paths(datadir, declared_paths, paths, lookup_invocation)
      resolved_paths = []
      unless paths.nil? || datadir.nil?
        ext = path_extension
        paths.each_with_index do |path, idx|
          path = path + ext unless path.end_with?(ext)
          resolved_paths << ResolvedPath.new(declared_paths[idx], datadir + path)
        end
      end
      resolved_paths
    end

    def path_extension
      raise NotImplementedError, "Subclass of FileBasedProviderFactory must implement 'path_extension' method"
    end
    protected :path_extension
  end
end
