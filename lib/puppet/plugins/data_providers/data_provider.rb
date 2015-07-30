module Puppet::Plugins::DataProviders
  module DataProvider
    # Performs a lookup.
    #
    # @param key [String] The key to lookup
    # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
    # @param merge [String|Hash<String,Object>|nil] Merge strategy or hash with strategy and options
    #
    # @api public
    def lookup(key, scope, merge)
      hash = data(data_key(key), scope)
      value = hash[key]
      throw :no_such_key unless value || hash.include?(key)
      value
    end

    # Gets the data from the compiler, or initializes it by calling #initialize_data if not present in the compiler.
    # This means, that data is initialized once per compilation, and the data is cached for as long as the compiler
    # lives (which is for one catalog production). This makes it possible to return data that is tailored for the
    # request.
    #
    # If data is obtained using the #initialize_data method it will be sent to the #validate_data for validation
    #
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
    # @return [Hash] The data hash for the given _key_
    #
    # @api public
    def data(data_key, scope)
      compiler = scope.compiler
      adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
      adapter.data[data_key] ||= validate_data(initialize_data(data_key, scope), data_key)
    end
    protected :data

    # Obtain an optional key to use when retrieving the data.
    #
    # @param key [String] The key to lookup
    # @return [String,nil] The data key or nil if not applicable
    #
    # @api public
    def data_key(key)
      nil
    end
    protected :data_key

    # Should be reimplemented by subclass to provide the hash that corresponds to the given name.
    #
    # @param data_key [String] The data key such as the name of a module or the constant 'environment'
    # @param scope [Puppet::Parser::Scope] The scope to use for the lookup
    # @return [Hash] The hash of values
    #
    # @api public
    def initialize_data(data_key, scope)
      {}
    end
    protected :initialize_data

    def validate_data(data, data_key)
      data
    end
    protected :validate_data
  end

  class ModuleDataProvider
    include DataProvider

    # Retrieve the first segment of the qualified name _key_. This method will throw
    # :no_such_key unless the segment can be extracted.
    #
    # @param key [String] The key
    # @return [String] The first segment of the given key
    def data_key(key)
      # Do not attempt to do a lookup in a module unless the name is qualified.
      qual_index = key.index('::')
      throw :no_such_key if qual_index.nil?
      key[0..qual_index-1]
    end
    protected :data_key

    # Assert that all keys in the given _data_ are prefixed with the given _module_name_.
    #
    # @param data [Hash] The data hash
    # @param module_name [String] The name of the module where the data was found
    # @return [Hash] The data_hash unaltered
    def validate_data(data, module_name)
      module_prefix = "#{module_name}::"
      data.each_key do |k|
        unless k.is_a?(String) && k.start_with?(module_prefix)
          raise Puppet::DataBinding::LookupError, "Module data for module '#{module_name}' must use keys qualified with the name of the module"
        end
      end
    end
    protected :validate_data
  end

  class EnvironmentDataProvider
    include DataProvider

    def data_key(key)
      'environment'
    end
    protected :data_key
  end
end
