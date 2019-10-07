module Puppet
module Pal
  # A FunctionSignature is returned from `function_signature`. Its purpose is to answer questions about the function's parameters
  # and if it can be called with a set of parameters.
  #
  # It is also possible to get an array of puppet Callable data type where each callable describes one possible way
  # the function can be called.
  #
  # @api public
  #
  class FunctionSignature
    # @api private
    def initialize(function_class)
      @func = function_class
    end

    # Returns true if the function can be called with the given arguments and false otherwise.
    # If the function is not callable, and a code block is given, it is given a formatted error message that describes
    # the type mismatch. That error message can be quite complex if the function has multiple dispatch depending on
    # given types.
    #
    # @param args [Array] The arguments as given to the function call
    # @param callable [Proc, nil] An optional ruby Proc or puppet lambda given to the function
    # @yield [String] a formatted error message describing a type mismatch if the function is not callable with given args + block
    # @return [Boolean] true if the function can be called with given args + block, and false otherwise
    # @api public
    #
    def callable_with?(args, callable=nil)
      signatures = @func.dispatcher.to_type
      callables = signatures.is_a?(Puppet::Pops::Types::PVariantType) ? signatures.types : [signatures]

      return true if callables.any? {|t| t.callable_with?(args) }
      return false unless block_given?
      args_type = Puppet::Pops::Types::TypeCalculator.singleton.infer_set(callable.nil? ? args : args + [callable])
      error_message = Puppet::Pops::Types::TypeMismatchDescriber.describe_signatures(@func.name, @func.signatures, args_type)
      yield error_message
      false
    end

    # Returns an array of Callable puppet data type
    # @return [Array<Puppet::Pops::Types::PCallableType] one callable per way the function can be called
    #
    # @api public
    #
    def callables
      signatures = @func.dispatcher.to_type
      signatures.is_a?(Puppet::Pops::Types::PVariantType) ? signatures.types : [signatures]
    end
  end

end
end
