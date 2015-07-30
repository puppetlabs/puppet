module Puppet::DataProviders::DataFunctionSupport
  def initialize_data(data_key, scope)
    name = "#{data_key}::data"
      Puppet::Util::Profiler.profile("Called #{name}", [ :functions, name ]) do
      loader = loader(data_key, scope)
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
