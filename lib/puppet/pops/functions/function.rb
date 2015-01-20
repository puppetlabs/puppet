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
  def call(scope, *args)
    self.class.dispatcher.dispatch(self, scope, args)
  end

  # Allows the implementation of a function to call other functions by name. The callable functions
  # are those visible to the same loader that loaded this function (the calling function).
  #
  # @api public
  def call_function(function_name, *args)
    the_loader = loader
    scope = closure_scope
    raise ArgumentError, "Function #{self.class.name}(): cannot call function '#{function_name}' - no loader specified" unless the_loader

    func = the_loader.load(:function, function_name)
    return func.call(scope, *args) if func

    # Check if a 3x function is present. Raise a generic error if it's not to allow upper layers to fill in the details
    # about where in a puppet manifest this error originates. (Such information is not available here).
    func_3x = Puppet::Parser::Functions.function(function_name)
    raise ArgumentError, "Function #{self.class.name}(): cannot call function '#{function_name}' - not found" unless func_3x

    # Call via 3x API
    # Arguments must be mapped since functions are unaware of the new and magical creatures in 4x.
    result = scope.send(func_3x, converter.convert_args(args, scope))

    # Prevent non r-value functions from leaking their result (they are not written to care about this)
    Puppet::Parser::Functions.rvalue?(function_name) ? result : nil
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

  def converter
    @@converter ||= ArgConverter.new
  end
end

class ArgConverter
  include Puppet::Pops::Evaluator::Runtime3Support

  def convert_args(args, scope)
    # NOTE: Passing an empty string last converts nil/:undef to empty string
    args.map {|a| convert(a, scope, '') }
  end
end