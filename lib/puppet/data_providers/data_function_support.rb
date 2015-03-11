module Puppet::DataProviders::DataFunctionSupport
  # Gets the data from the compiler, or initializes it from a function call if not present in the compiler.
  # This means, that the function providing the data is called once per compilation, and the data is cached for
  # as long as the compiler lives (which is for one catalog production).
  # This makes it possible to return data that is tailored for the request.
  # The class including this module must implement `loader(scope)` to return the apropriate loader.
  #
  # If a block is given, it will be called to validate the data hash when it is retrieved from a function call. The
  # block must return the validated data or raise a {Puppet::Error} to indicate that the data is invalid.
  # The block is not called when the data is found in the compiler or in the cache.
  #
  # @param key [String] The data key such as the name of a module or the constant 'environment'
  # @param scope [Parser::Scope] The scope
  # @return [Hash] The data hash for the given _key_
  # @yield An optional block that can be used for validation of the data returned from the function
  # @yieldparam [Hash] data The data to validate
  # @yieldreturn [Hash] The validated data
  #
  def data(key, scope, &block)
    compiler = scope.compiler
    adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
    adapter.data[key] ||= initialize_data_from_function("#{key}::data", key, scope, &block)
  end

  def initialize_data_from_function(name, key, scope)
    Puppet::Util::Profiler.profile("Called #{name}", [ :functions, name ]) do
      loader = loader(key, scope)
      if loader && func = loader.load(:function, name)
        # function found, call without arguments, must return a Hash
        # TODO: Validate the function - to ensure it does not contain unwanted side effects
        #       That can only be done if the function is a puppet function
        #
        result = func.call(scope)
        unless result.is_a?(Hash)
          raise Puppet::Error.new("Expected '#{name}' function to return a Hash, got #{result.class}")
        end
        # validate result if block given
        result = yield(result) if block_given?
      else
        raise Puppet::Error.new("Data from 'function' cannot find the required '#{name}' function")
      end
      result
    end
  end
end
