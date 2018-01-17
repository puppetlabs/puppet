# @note WARNING: This new function API is still under development and may change at
#   any time
#
# A function in the puppet evaluator.
#
# Functions are normally defined by another system, which produces subclasses
# of this class as well as constructing delegations to call the appropriate methods.
#
# This class should rarely be used directly. Instead functions should be
# constructed using {Puppet::Functions.create_function}.
#
# @api public
class Puppet::Pops::Functions::Function
  # The scope where the function was defined
  attr_reader :closure_scope

  # The loader that loaded this function.
  # Should be used if function wants to load other things.
  #
  attr_reader :loader

  def initialize(closure_scope, loader)
    @closure_scope = closure_scope
    @loader = loader
  end

  # Invokes the function via the dispatching logic that performs type check and weaving.
  # A specialized function may override this method to do its own dispatching and checking of
  # the raw arguments. A specialized implementation can rearrange arguments, add or remove
  # arguments and then delegate to the dispatching logic by calling:
  #
  # @example Delegating to the dispatcher
  #     def call(scope, *args)
  #       manipulated_args = args + ['easter_egg']
  #       self.class.dispatcher.dispatch(self, scope, manipulated_args)
  #     end
  #
  # System functions that must have access to the calling scope can use this technique. Functions
  # in general should not need the calling scope. (The closure scope; what is visible where the function
  # is defined) is available via the method `closure_scope`).
  #
  # @api public
  def call(scope, *args, &block)
    begin
      result = catch(:return) do
        return self.class.dispatcher.dispatch(self, scope, args, &block)
      end
      return result.value
    rescue Puppet::Pops::Evaluator::Next => jumper
      begin
        throw :next, jumper.value
      rescue Puppet::Parser::Scope::UNCAUGHT_THROW_EXCEPTION
        raise Puppet::ParseError.new("next() from context where this is illegal", jumper.file, jumper.line)
      end
    rescue Puppet::Pops::Evaluator::Return => jumper
      begin
        throw :return, jumper
      rescue Puppet::Parser::Scope::UNCAUGHT_THROW_EXCEPTION
        raise Puppet::ParseError.new("return() from context where this is illegal", jumper.file, jumper.line)
      end
    end
  end

  # Allows the implementation of a function to call other functions by name. The callable functions
  # are those visible to the same loader that loaded this function (the calling function). The
  # referenced function is called with the calling functions closure scope as the caller's scope.
  #
  # @param function_name [String] The name of the function
  # @param *args [Object] splat of arguments
  # @return [Object] The result returned by the called function
  #
  # @api public
  def call_function(function_name, *args, &block)
    internal_call_function(closure_scope, function_name, args, &block)
  end

  def closure_scope
    # If closure scope is explicitly set to not nil, if there is a global scope, otherwise an empty hash
    @closure_scope || Puppet.lookup(:global_scope) { {} }
  end

  # The dispatcher for the function
  #
  # @api private
  def self.dispatcher
    @dispatcher ||= Puppet::Pops::Functions::Dispatcher.new
  end

  # Produces information about parameters in a way that is compatible with Closure
  #
  # @api private
  def self.signatures
    @dispatcher.signatures
  end

  protected

  # Allows the implementation of a function to call other functions by name and pass the caller
  # scope. The callable functions are those visible to the same loader that loaded this function
  # (the calling function).
  #
  # @param scope [Puppet::Parser::Scope] The caller scope
  # @param function_name [String] The name of the function
  # @param args [Array] array of arguments
  # @return [Object] The result returned by the called function
  #
  # @api public
  def internal_call_function(scope, function_name, args, &block)

    the_loader = loader
    unless the_loader
      raise ArgumentError, _("Function %{class_name}(): cannot call function '%{function_name}' - no loader specified") %
          { class_name: self.class.name, function_name: function_name }
    end

    func = the_loader.load(:function, function_name)
    if func
      Puppet::Util::Profiler.profile(function_name, [:functions, function_name]) do
        return func.call(scope, *args, &block)
      end
    end

    # Check if a 3x function is present. Raise a generic error if it's not to allow upper layers to fill in the details
    # about where in a puppet manifest this error originates. (Such information is not available here).
    loader_scope = closure_scope
    func_3x = Puppet::Parser::Functions.function(function_name, loader_scope.environment) if loader_scope.is_a?(Puppet::Parser::Scope)
    unless func_3x
      raise ArgumentError, _("Function %{class_name}(): Unknown function: '%{function_name}'") %
          { class_name: self.class.name, function_name: function_name }
    end

    # Call via 3x API
    # Arguments must be mapped since functions are unaware of the new and magical creatures in 4x.
    # NOTE: Passing an empty string last converts nil/:undef to empty string
    result = scope.send(func_3x, Puppet::Pops::Evaluator::Runtime3FunctionArgumentConverter.map_args(args, loader_scope, ''), &block)

    # Prevent non r-value functions from leaking their result (they are not written to care about this)
    Puppet::Parser::Functions.rvalue?(function_name) ? result : nil
  end

end
