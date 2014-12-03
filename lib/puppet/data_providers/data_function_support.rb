module Puppet::DataProviders::DataFunctionSupport
  # Gets the data from the compiler, or initializes it from a function call if not present in the compiler.
  # This means, that the function providing the data is called once per compilation, and the data is cached for
  # as long as the compiler lives (which is for one catalog production).
  # This makes it possible to return data that is tailored for the request.
  # The class including this module must implement `loader(scope)` to return the apropriate loader.
  #
  def data(key, scope)
    compiler = scope.compiler
    adapter = Puppet::DataProviders::DataAdapter.get(compiler) || Puppet::DataProviders::DataAdapter.adapt(compiler)
    adapter.data[key] ||= initialize_data_from_function("#{key}::data", scope)
  end

  def initialize_data_from_function(name, scope)
    Puppet::Util::Profiler.profile("Called #{name}", [ :functions, name ]) do
      loader = loader(scope)
      if loader && func = loader.load(:function, name)
        # function found, call without arguments, must return a Hash
        # TODO: Validate the function - to ensure it does not contain unwanted side effects
        #       That can only be done if the function is a puppet function
        #
        result = func.call(scope)
        unless result.is_a?(Hash)
          raise Puppet::Error.new("Expected '#{name}' function to return a Hash, got #{result.class}")
        end
      else
        raise Puppet::Error.new("Data from 'function' cannot find the required '#{name}' function")
      end
      result
    end
  end
end
