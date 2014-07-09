# @note WARNING: This new function API is still under development and may change at any time
#
# Functions in the puppet language can be written in Ruby and distributed in
# puppet modules. The function is written by creating a file in the module's
# `lib/puppet/functions/<modulename>` directory, where `<modulename>` is
# replaced with the module's name. The file should have the name of the function.
# For example, to create a function named `min` in a module named `math` create
# a file named `lib/puppet/functions/math/min.rb` in the module.
#
# A function is implemented by calling {Puppet::Functions.create_function}, and
# passing it a block that defines the implementation of the function.
#
# Functions are namespaced inside the module that contains them. The name of
# the function is prefixed with the name of the module. For example,
# `math::min`.
#
# @example A simple function
#   Puppet::Functions.create_function('math::min') do
#     def min(a, b)
#       a <= b ? a : b
#     end
#   end
#
# Anatomy of a function
# ---
#
# Functions are composed of four parts: the name, the implementation methods,
# the signatures, and the dispatches.
#
# The name is the string given to the {Puppet::Functions.create_function}
# method. It specifies the name to use when calling the function in the puppet
# language, or from other functions.
#
# The implementation methods are ruby methods (there can be one or more) that
# provide that actual implementation of the function's behavior. In the
# simplest case the name of the function (excluding any namespace) and the name
# of the method are the same. When that is done no other parts (signatures and
# dispatches) need to be used.
#
# Signatures are a way of specifying the types of the function's parameters.
# The types of any arguments will be checked against the types declared in the
# signature and an error will be produced if they don't match. The types are
# defined by using the same syntax for types as in the puppet language.
#
# Dispatches are how signatures and implementation methods are tied together.
# When the function is called, puppet searches the signatures for one that
# matches the supplied arguments. Each signature is part of a dispatch, which
# specifies the method that should be called for that signature. When a
# matching signature is found, the corrosponding method is called.
#
# Documentation for the function should be placed as comments to the
# implementation method(s).
#
# @todo Documentation for individual instances of these new functions is not
#   yet tied into the puppet doc system.
#
# @example Dispatching to different methods by type
#   Puppet::Functions.create_function('math::min') do
#     dispatch :numeric_min do
#       param 'Numeric', 'a'
#       param 'Numeric', 'b'
#     end
#
#     dispatch :string_min do
#       param 'String', 'a'
#       param 'String', 'b'
#     end
#
#     def numeric_min(a, b)
#       a <= b ? a : b
#     end
#
#     def string_min(a, b)
#       a.downcase <= b.downcase ? a : b
#     end
#   end
#
# Specifying Signatures
# ---
#
# If nothing is specified, the number of arguments given to the function must
# be the same as the number of parameters, and all of the parameters are of
# type 'Any'.
#
# To express that the last parameter captures the rest, the method
# `last_captures_rest` can be called. This indicates that the last parameter is
# a varargs parameter and will be passed to the implementing method as an array
# of the given type.
#
# When defining a dispatch for a function, the resulting dispatch matches
# against the specified argument types and min/max occurrence of optional
# entries. When the dispatch makes the call to the implementation method the
# arguments are simply passed and it is the responsibility of the method's
# implementor to ensure it can handle those arguments (i.e. there is no check
# that what was declared as optional actually has a default value, and that
# a "captures rest" is declared using a `*`).
#
# @example Varargs
#   Puppet::Functions.create_function('foo') do
#     dispatch :foo do
#       param 'Numeric', 'first'
#       param 'Numeric', 'values'
#       last_captures_rest
#     end
#
#     def foo(first, *values)
#       # do something
#     end
#   end
#
# Access to Scope
# ---
# In general, functions should not need access to scope; they should be
# written to act on their given input only. If they absolutely must look up
# variable values, they should do so via the closure scope (the scope where
# they are defined) - this is done by calling `closure_scope()`.
#
# Calling other Functions
# ---
# Calling other functions by name is directly supported via
# {Puppet::Pops::Functions::Function#call_function}. This allows a function to
# call other functions visible from its loader.
#
# @api public
module Puppet::Functions
  # @param func_name [String, Symbol] a simple or qualified function name
  # @param block [Proc] the block that defines the methods and dispatch of the
  #   Function to create
  # @return [Class<Function>] the newly created Function class
  #
  # @api public
  def self.create_function(func_name, function_base = Function, &block)
    if function_base.ancestors.none? { |s| s == Puppet::Pops::Functions::Function }
      raise ArgumentError, "Functions must be based on Puppet::Pops::Functions::Function. Got #{function_base}"
    end

    func_name = func_name.to_s
    # Creates an anonymous class to represent the function
    # The idea being that it is garbage collected when there are no more
    # references to it.
    #
    the_class = Class.new(function_base, &block)

    # Make the anonymous class appear to have the class-name <func_name>
    # Even if this class is not bound to such a symbol in a global ruby scope and
    # must be resolved via the loader.
    # This also overrides any attempt to define a name method in the given block
    # (Since it redefines it)
    #
    # TODO, enforce name in lower case (to further make it stand out since Ruby
    # class names are upper case)
    #
    the_class.instance_eval do
      @func_name = func_name
      def name
        @func_name
      end
    end

    # Automatically create an object dispatcher based on introspection if the
    # loaded user code did not define any dispatchers. Fail if function name
    # does not match a given method name in user code.
    #
    if the_class.dispatcher.empty?
      simple_name = func_name.split(/::/)[-1]
      type, names = default_dispatcher(the_class, simple_name)
      last_captures_rest = (type.size_range[1] == Puppet::Pops::Types::INFINITY)
      the_class.dispatcher.add_dispatch(type, simple_name, names, nil, nil, nil, last_captures_rest)
    end

    # The function class is returned as the result of the create function method
    the_class
  end

  # Creates a default dispatcher configured from a method with the same name as the function
  #
  # @api private
  def self.default_dispatcher(the_class, func_name)
    unless the_class.method_defined?(func_name)
      raise ArgumentError, "Function Creation Error, cannot create a default dispatcher for function '#{func_name}', no method with this name found"
    end
    any_signature(*min_max_param(the_class.instance_method(func_name)))
  end

  # @api private
  def self.min_max_param(method)
    # Ruby 1.8.7 does not have support for details about parameters
    if method.respond_to?(:parameters)
      result = {:req => 0, :opt => 0, :rest => 0 }
      # TODO: Optimize into one map iteration that produces names map, and sets
      # count as side effect
      method.parameters.each { |p| result[p[0]] += 1 }
      from = result[:req]
      to = result[:rest] > 0 ? :default : from + result[:opt]
      names = method.parameters.map {|p| p[1].to_s }
    else
      # Cannot correctly compute the signature in Ruby 1.8.7 because arity for
      # optional values is screwed up (there is no way to get the upper limit),
      # an optional looks the same as a varargs In this case - the failure will
      # simply come later when the call fails
      #
      arity = method.arity
      from = arity >= 0 ? arity : -arity -1
      to = arity >= 0 ? arity : :default  # i.e. infinite (which is wrong when there are optional - flaw in 1.8.7)
      names = [] # no names available
    end
    [from, to, names]
  end

  # Construct a signature consisting of Object type, with min, and max, and given names.
  # (there is only one type entry).
  #
  # @api private
  def self.any_signature(from, to, names)
    # Construct the type for the signature
    # Tuple[Object, from, to]
    factory = Puppet::Pops::Types::TypeFactory
    [factory.callable(factory.any, from, to), names]
  end

  # Function
  # ===
  # This class is the base class for all Puppet 4x Function API functions. A
  # specialized class is created for each puppet function.
  #
  # @api public
  class Function < Puppet::Pops::Functions::Function

    # @api private
    def self.builder
      @type_parser ||= Puppet::Pops::Types::TypeParser.new
      @all_callables ||= Puppet::Pops::Types::TypeFactory.all_callables
      DispatcherBuilder.new(dispatcher, @type_parser, @all_callables)
    end

    # Dispatch any calls that match the signature to the provided method name.
    #
    # @param meth_name [Symbol] The name of the implementation method to call
    #   when the signature defined in the block matches the arguments to a call
    #   to the function.
    # @return [Void]
    #
    # @api public
    def self.dispatch(meth_name, &block)
      builder().instance_eval do
        dispatch(meth_name, &block)
      end
    end
  end

  # Public api methods of the DispatcherBuilder are available within dispatch()
  # blocks declared in a Puppet::Function.create_function() call.
  #
  # @api public
  class DispatcherBuilder
    # @api private
    def initialize(dispatcher, type_parser, all_callables)
      @type_parser = type_parser
      @all_callables = all_callables
      @dispatcher = dispatcher
    end

    # Defines a positional parameter with type and name
    #
    # @param type [String] The type specification for the parameter.
    # @param name [String] The name of the parameter. This is primarily used
    #   for error message output and does not have to match the name of the
    #   parameter on the implementation method.
    # @return [Void]
    #
    # @api public
    def param(type, name)
      if type.is_a?(String)
        @types << type
        @names << name
        # mark what should be picked for this position when dispatching
        @weaving << @names.size()-1
      else
        raise ArgumentError, "Type signature argument must be a String reference to a Puppet Data Type. Got #{type.class}"
      end
    end

    # Defines one required block parameter that may appear last. If type and name is missing the
    # default type is "Callable", and the name is "block". If only one
    # parameter is given, then that is the name and the type is "Callable".
    #
    # @api public
    def required_block_param(*type_and_name)
      case type_and_name.size
      when 0
        # the type must be an independent instance since it will be contained in another type
        type = @all_callables.copy
        name = 'block'
      when 1
        # the type must be an independent instance since it will be contained in another type
        type = @all_callables.copy
        name = type_and_name[0]
      when 2
        type_string, name = type_and_name
        type = @type_parser.parse(type_string)
      else
        raise ArgumentError, "block_param accepts max 2 arguments (type, name), got #{type_and_name.size}."
      end

      unless Puppet::Pops::Types::TypeCalculator.is_kind_of_callable?(type, false)
        raise ArgumentError, "Expected PCallableType or PVariantType thereof, got #{type.class}"
      end

      unless name.is_a?(String) || name.is_a?(Symbol)
        raise ArgumentError, "Expected block_param name to be a String or Symbol, got #{name.class}"
      end

      if @block_type.nil?
        @block_type = type
        @block_name = name
      else
        raise ArgumentError, "Attempt to redefine block"
      end
    end

    # Defines one optional block parameter that may appear last. If type or name is missing the
    # defaults are "any callable", and the name is "block". The implementor of the dispatch target
    # must use block = nil when it is optional (or an error is raised when the call is made).
    #
    # @api public
    def optional_block_param(*type_and_name)
      # same as required, only wrap the result in an optional type
      required_block_param(*type_and_name)
      @block_type = Puppet::Pops::Types::TypeFactory.optional(@block_type)
    end

    # Specifies the min and max occurance of arguments (of the specified types)
    # if something other than the exact count from the number of specified
    # types). The max value may be specified as :default if an infinite number of
    # arguments are supported. When max is > than the number of specified
    # types, the last specified type repeats.
    #
    # @api public
    def arg_count(min_occurs, max_occurs)
      @min = min_occurs
      @max = max_occurs
      unless min_occurs.is_a?(Integer) && min_occurs >= 0
        raise ArgumentError, "min arg_count of function parameter must be an Integer >=0, got #{min_occurs.class} '#{min_occurs}'"
      end
      unless max_occurs == :default || (max_occurs.is_a?(Integer) && max_occurs >= 0)
        raise ArgumentError, "max arg_count of function parameter must be an Integer >= 0, or :default, got #{max_occurs.class} '#{max_occurs}'"
      end
      unless max_occurs == :default || (max_occurs.is_a?(Integer) && max_occurs >= min_occurs)
        raise ArgumentError, "max arg_count must be :default (infinite) or >= min arg_count, got min: '#{min_occurs}, max: '#{max_occurs}'"
      end
    end

    # Specifies that the last argument captures the rest.
    #
    # @api public
    def last_captures_rest
      @last_captures = true
    end

    private

    # @api private
    def dispatch(meth_name, &block)
      # an array of either an index into names/types, or an array with
      # injection information [type, name, injection_name] used when the call
      # is being made to weave injections into the given arguments.
      #
      @types = []
      @names = []
      @weaving = []
      @injections = []
      @min = nil
      @max = nil
      @last_captures = false
      @block_type = nil
      @block_name = nil
      self.instance_eval &block
      callable_t = create_callable(@types, @block_type, @min, @max)
      @dispatcher.add_dispatch(callable_t, meth_name, @names, @block_name, @injections, @weaving, @last_captures)
    end

    # Handles creation of a callable type from strings specifications of puppet
    # types and allows the min/max occurs of the given types to be given as one
    # or two integer values at the end.  The given block_type should be
    # Optional[Callable], Callable, or nil.
    #
    # @api private
    def create_callable(types, block_type, from, to)
      mapped_types = types.map do |t|
        @type_parser.parse(t)
      end

      if !(from.nil? && to.nil?)
        mapped_types << from
        mapped_types << to
      end

      if block_type
        mapped_types << block_type
      end

      Puppet::Pops::Types::TypeFactory.callable(*mapped_types)
    end
  end

  private

  # @note WARNING: This style of creating functions is not public. It is a system
  #   under development that will be used for creating "system" functions.
  #
  # This is a private, internal, system for creating functions. It supports
  # everything that the public function definition system supports as well as a
  # few extra features.
  #
  # Injection Support
  # ===
  # The Function API supports injection of data and services. It is possible to
  # make injection that takes effect when the function is loaded (for services
  # and runtime configuration that does not change depending on how/from where
  # in what context the function is called. It is also possible to inject and
  # weave argument values into a call.
  #
  # Injection of attributes
  # ---
  # Injection of attributes is performed by one of the methods `attr_injected`,
  # and `attr_injected_producer`.  The injected attributes are available via
  # accessor method calls.
  #
  # @example using injected attributes
  #   Puppet::Functions.create_function('test') do
  #     attr_injected String, :larger, 'message_larger'
  #     attr_injected String, :smaller, 'message_smaller'
  #     def test(a, b)
  #       a > b ? larger() : smaller()
  #     end
  #   end
  #
  # @api private
  class InternalFunction < Function
    # @api private
    def self.builder
      @type_parser ||= Puppet::Pops::Types::TypeParser.new
      @all_callables ||= Puppet::Pops::Types::TypeFactory.all_callables
      InternalDispatchBuilder.new(dispatcher, @type_parser, @all_callables)
    end

    # Defines class level injected attribute with reader method
    #
    # @api private
    def self.attr_injected(type, attribute_name, injection_name = nil)
      define_method(attribute_name) do
        ivar = :"@#{attribute_name.to_s}"
        unless instance_variable_defined?(ivar)
          injector = Puppet.lookup(:injector)
          instance_variable_set(ivar, injector.lookup(closure_scope, type, injection_name))
        end
        instance_variable_get(ivar)
      end
    end

    # Defines class level injected producer attribute with reader method
    #
    # @api private
    def self.attr_injected_producer(type, attribute_name, injection_name = nil)
      define_method(attribute_name) do
        ivar = :"@#{attribute_name.to_s}"
        unless instance_variable_defined?(ivar)
          injector = Puppet.lookup(:injector)
          instance_variable_set(ivar, injector.lookup_producer(closure_scope, type, injection_name))
        end
        instance_variable_get(ivar)
      end
    end
  end

  # @note WARNING: This style of creating functions is not public. It is a system
  #   under development that will be used for creating "system" functions.
  #
  # Injection and Weaving of parameters
  # ---
  # It is possible to inject and weave parameters into a call. These extra
  # parameters are not part of the parameters passed from the Puppet logic, and
  # they can not be overridden by parameters given as arguments in the call.
  # They are invisible to the Puppet Language.
  #
  # @example using injected parameters
  #   Puppet::Functions.create_function('test') do
  #     dispatch :test do
  #       param 'Scalar', 'a'
  #       param 'Scalar', 'b'
  #       injected_param 'String', 'larger', 'message_larger'
  #       injected_param 'String', 'smaller', 'message_smaller'
  #     end
  #     def test(a, b, larger, smaller)
  #       a > b ? larger : smaller
  #     end
  #   end
  #
  # The function in the example above is called like this:
  #
  #     test(10, 20)
  #
  # Using injected value as default
  # ---
  # Default value assignment is handled by using the regular Ruby mechanism (a
  # value is assigned to the variable).  The dispatch simply indicates that the
  # value is optional. If the default value should be injected, it can be
  # handled different ways depending on what is desired:
  #
  # * by calling the accessor method for an injected Function class attribute.
  #   This is suitable if the value is constant across all instantiations of the
  #   function, and across all calls.
  # * by injecting a parameter into the call
  #   to the left of the parameter, and then assigning that as the default value.
  # * One of the above forms, but using an injected producer instead of a
  #   directly injected value.
  #
  # @example method with injected default values
  #   Puppet::Functions.create_function('test') do
  #     dispatch :test do
  #       injected_param String, 'b_default', 'b_default_value_key'
  #       param 'Scalar', 'a'
  #       param 'Scalar', 'b'
  #     end
  #     def test(b_default, a, b = b_default)
  #       # ...
  #     end
  #   end
  #
  # @api private
  class InternalDispatchBuilder < DispatcherBuilder
    def scope_param()
      @injections << [:scope, 'scope', '', :dispatcher_internal]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size()-1]
    end
    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    # @api private
    def injected_param(type, name, injection_name = '')
      @injections << [type, name, injection_name]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size() -1]
    end

    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    # @api private
    def injected_producer_param(type, name, injection_name = '')
      @injections << [type, name, injection_name, :producer]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size()-1]
    end
  end
end
