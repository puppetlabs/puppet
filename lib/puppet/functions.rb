module Puppet::Functions
  # Creates a new Puppet Function Class with the given func_name with
  # functionality defined by the given block.  The func name should be an
  # unqualified lower case name. The block is evaluated as when a derived Ruby
  # class is created and it is intended (in the simplest case) that the user
  # defines the actual function in a method named the same as the function (as
  # shown in the first example below).
  #
  # @example A simple function
  #   Puppet::Functions.create_function('min') do
  #     def min(a, b)
  #       a <= b ? a : b
  #     end
  #   end
  #
  # Documentation for the function should be placed as comments to the
  # method(s) that define the functionality The simplest form of defining a
  # function introspects the method signature (in the example `min(a,b)`) and
  # infers that this means that there are 2 required arguments of Object type.
  # If something else is wanted the method `dispatch` should be called in the
  # block defining the function to define the details of dispatching a call of
  # the function.
  #
  # In the next example, the function is enhanced to check that arguments are
  # of numeric type.
  #
  # @example dispatch and type checking
  #   Puppet::Functions.create_function('min') do
  #     dispatch :min do
  #       param Numeric, 'a'
  #       param Numeric, 'b'
  #     end
  #
  #     def min(a, b)
  #       a <= b ? a : b
  #     end
  #   end
  #
  # It is possible to specify multiple type signatures as defined by the param
  # specification in the dispatch method, and dispatch to the same, or
  # alternative methods.  When a call is processed the given type signatures
  # are tested in the order they were defined - the first signature with
  # matching type wins.
  #
  # Type arguments may be Puppet Type References in String form or Ruby classes
  # (for basic types). To make type creation convenient, the logic that builds
  # a dispatcher redirects any calls to the type factory.
  #
  # Argument Count and Capture Rest
  # ---
  # If nothing is specified, the number of arguments given to the function must
  # be the same as the number of parameters (parameters that perform injection
  # not included). If something else is wanted, the method `arg_count`
  # specifies the minimum and maximum number of given arguments. Thus, to
  # indicate that parameters are optional, set min to a value lower than the
  # number of specified parameters, and max to the number of specified
  # parameters.
  #
  # To express that the last parameter captures the rest, the method
  # `last_captures_rest` can be called. This is an indicator to those that
  # obtain information about the function (for the purpose of displaying error
  # messages etc.) For a Function, there the call is processed the same way
  # irrespective how the `last_captures_rest`, and it is up to the implementor
  # of the target method to decide who the specified min/max number of
  # arguments are laid out.  This is shown in the following example:
  #
  # @example variable number of args to
  #   dispatch :foo do
  #     param Numeric, 'up_to_five_numbers'
  #     arg_count 1, 5
  #   end
  #
  #   def foo(a, b=0, c=0, *d)
  #     ...
  #   end
  #
  # Access to Scope
  # ---
  # In general, functions should not need access to scope; they should be
  # written to act on their given input only. If they absolutely must look up
  # variable values, they should do so via the closure scope (the scope where
  # they are defined) - this is done by calling `closure_scope()`.
  #
  # For Puppet System Functions where access to the calling scope may be
  # essential the implementor of the function may override the `Function.call`
  # method to pass the scope on to the method(s) implementing the body of the
  # function.
  #
  # Calling other Functions
  # ---
  # Calling other functions by name is directly supported via
  # `call_funcion(name, *args)`. This allows a function to call other functions
  # visible from its loader.
  #
  # @todo Optimizations
  #
  #   Unoptimized implementation. The delegation chain is longer than required,
  #   and arguments are passed with splat.  The chain Function -> class ->
  #   Dispatcher -> Dispatch -> Visitor can be shortened for non polymorph
  #   dispatching.  Also, when there is only one signature (single Dispatch), a
  #   different Dispatcher could short circuit the search.
  #
  # @param func_name [String, Symbol] a simple or qualified function name
  # @param &block [Proc] the block that defines the methods and dispatch of the
  #   Function to create
  # @return [Class<Function>] the newly created Function class
  #
  # @api public
  def self.create_function(func_name, function_base = Function, &block)
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
    object_signature(*min_max_param(the_class.instance_method(func_name)))
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
  # (there is only one type entry). Note that this signature is Object, not Optional[Object].
  #
  # @api private
  def self.object_signature(from, to, names)
    # Construct the type for the signature
    # Tuple[Object, from, to]
    factory = Puppet::Pops::Types::TypeFactory
    [factory.callable(factory.object, from, to), names]
  end

  # Function
  # ===
  # This class is the base class for all Puppet 4x Function API functions. A
  # specialized class is created for each puppet function.  Most methods act on
  # the class, except `call`, `closure_scope`, and `loader` which are bound to
  # a particular instance of the function (it is aware of its runtime context).
  #
  # @api public
  class Function < Puppet::Pops::Functions::Function

    # @api private
    def self.builder
      DispatcherBuilder.new(dispatcher)
    end

    # @api public
    def self.dispatch(meth_name, &block)
      builder().instance_eval do
        dispatch(meth_name, &block)
      end
    end
  end

  # Public api methods of the DispatcherBuilder are available within dispatch()
  # blocks declared in a Puppet::Function.create_function() call.
  class DispatcherBuilder
    def initialize(dispatcher)
      @type_parser = Puppet::Pops::Types::TypeParser.new
      @all_callables = Puppet::Pops::Types::TypeFactory.all_callables
      @dispatcher = dispatcher
    end

    # Defines one parameter with type and name
    #
    # @api public
    def param(type, name)
      @types << type
      @names << name
      # mark what should be picked for this position when dispatching
      @weaving << @names.size()-1
    end

    # Defines one required block parameter that may appear last. If type and name is missing the
    # default type is "Callable", and the name is "block". If only one
    # parameter is given, then that is the name and the type is "Callable".
    #
    # @api public
    def required_block_param(*type_and_name)
      case type_and_name.size
      when 0
        type = @all_callables
        name = 'block'
      when 1
        type = @all_callables
        name = type_and_name[0]
      when 2
        type_string, name = type_and_name
        type = @type_parser.parse(type_string)
      else
        raise ArgumentError, "block_param accepts max 2 arguments (type, name), got #{type_and_name.size}."
      end

      unless type.is_a?(Puppet::Pops::Types::PCallableType)
        raise ArgumentError, "Expected PCallableType, got #{type.class}"
      end

      unless name.is_a?(String)
        raise ArgumentError, "Expected block_param name to be a String, got #{name.class}"
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
    # types). The max value may be specified as -1 if an infinite number of
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

    # Handles creation of a callable type from strings, puppet types, or ruby types and allows
    # the min/max occurs of the given types to be given as one or two integer values at the end.
    # The given block_type should be Optional[Callable], Callable, or nil.
    #
    # @api private
    def create_callable(types, block_type, from, to)
      mapped_types = types.map do |t|
        case t
        when String
          @type_parser.parse(t)
        when Class
          Puppet::Pops::Types::TypeFactory.type_of(t)
        else
          raise ArgumentError, "Type signature argument must be a Ruby Type Class, or a String reference to a Puppet Data Type. Got #{t.class}"
        end
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
  class InjectedFunction < Function
    def self.builder
      InjectedDispatchBuilder.new(dispatcher)
    end

    # Defines class level injected attribute with reader method
    #
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
  #       param Scalar, 'a'
  #       param Scalar, 'b'
  #       injected_param String, 'larger', 'message_larger'
  #       injected_param String, 'smaller', 'message_smaller'
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
  #       param Scalar, 'a'
  #       param Scalar, 'b'
  #     end
  #     def test(b_default, a, b = b_default)
  #       # ...
  #     end
  #   end
  #
  # @api private
  class InjectedDispatchBuilder < DispatcherBuilder
    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    def injected_param(type, name, injection_name = '')
      @injections << [type, name, injection_name]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size() -1]
    end

    # TODO: is param name really needed? Perhaps for error messages? (it is unused now)
    #
    def injected_producer_param(type, name, injection_name = '')
      @injections << [type, name, injection_name, :producer]
      # mark what should be picked for this position when dispatching
      @weaving << [@injections.size()-1]
    end
  end
end
