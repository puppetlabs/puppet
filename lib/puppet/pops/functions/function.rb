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
    if the_loader = loader
      func = the_loader.load(:function, function_name)
      if func
        return func.call(closure_scope, *args)
      end
    end
    # Raise a generic error to allow upper layers to fill in the details about where in a puppet manifest this
    # error originates. (Such information is not available here).
    #
    raise ArgumentError, "Function #{self.class.name}(): cannot call function '#{function_name}' - not found"
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
end
