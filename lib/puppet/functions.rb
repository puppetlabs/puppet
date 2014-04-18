module Puppet::Functions
  # Creates a new Puppet Function Class with the given func_name with functionality defined by the given block.
  # The func name should be an unqualified lower case name. The block is evaluated as when a derived Ruby class
  # is created and it is intended (in the simplest case) that the user defines the actual function in a method named
  # the same as the function (as shown in the first example below).
  #
  # @example A simple function
  #   Puppet::Functions.create_function('min') do
  #     def min(a, b)
  #       a <= b ? a : b
  #     end
  #   end
  #
  # Documentation for the function should be placed as comments to the method(s) that define the functionality
  # The simplest form of defining a function introspects the method signature (in the example `min(a,b)`) and
  # infers that this means that there are 2 required arguments of Object type. If something else is wanted
  # the method `dispatch` should be called in the block defining the function to define the details of dispatching
  # a call of the function.
  #
  # In the next example, the function is enhanced to check that arguments are of numeric type.
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
  # It is possible to specify multiple type signatures as defined by the param specification in the dispatch method, and
  # dispatch to the same, or alternative methods.
  # When a call is processed the given type signatures are tested in the order they were defined - the first signature
  # with matching type wins.
  #
  # Argument Count and Capture Rest
  # ---
  # If nothing is specified, the number of arguments given to the function must be the same as the number of parameters
  # (parameters that perform injection not included). If something else is wanted, the method `arg_count` specifies
  # the minimum and maximum number of given arguments. Thus, to indicate that parameters are optional, set min to
  # a value lower than the number of specified parameters, and max to the number of specified parameters.
  #
  # To express that the last parameter captures the rest, the method `last_captures_rest` can be called. This is
  # an indicator to those that obtain information about the function (for the purpose of displaying error messages etc.)
  # For a Function, there the call is processed the same way irrespective how the `last_captures_rest`, and it is up
  # to the implementor of the target method to decide who the specified min/max number of arguments are laid out.
  # This is shown in the following example:
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
  # Polymorphic Dispatch
  # ---
  # The dispatcher also supports polymorphic dispatch where the method to call is selected based on the type of the
  # first argument. It is possible to mix regular and polymorphic dispatching, the first with a matching signature wins
  # in all cases. (Typically one or the other dispatch type is selected for a given function).
  #
  # Polymorphic dispatch is based on a method prefix, followed by "_ClassName" where "ClassName" is the simple name
  # of the class of the first argument.
  #
  # @example using polymorphic dispatch
  #   Puppet::Functions.create_function('label') do
  #     dispatch_polymorph do
  #       param Object, 'label'
  #     end
  #
  #     def label_Object(o)
  #       "A Ruby object of class #{o.class}"
  #     end
  #
  #     def label_String(o)
  #       "A String with value '#{o}'"
  #     end
  #   end
  #
  # In this example, if the argument is a String, a special label is produced and for all others a generic label is
  # produced. It is now easy to add `label_` methods for other classes as needed without changing the dispatch.
  #
  # The type specification of the signature that follows the name of the method are given to the
  # `Puppet::Pops::Types::TypeFactory` to create a PTupleType.
  #
  # Arguments may be Puppet Type References in String form, Ruby classes (for basic types), or Puppet Type instances
  # as created by the Puppet::Pops::Types::TypeFactory. To make type creation convenient, the logic that builds a dispatcher
  # redirects any calls to the type factory.
  #
  # Injection Support
  # ===
  # The Function API supports injection of data and services. It is possible to make injection that takes effect
  # when the function is loaded (for services and runtime configuration that does not change depending on how/from where
  # in what context the function is called. It is also possible to inject and weave argument values into a call.
  #
  # Injection of attributes
  # ---
  # Injection of attributes is performed by one of the methods `attr_injected`, and `attr_injected_producer`.
  # The injected attributes are available via accessor method calls.
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
  # Injection and Weaving of parameters
  # ---
  # It is possible to inject and weave parameters into a call. These extra parameters are not part of
  # the parameters passed from the Puppet logic, and they can not be overridden by parameters given as arguments
  # in the call. They are invisible to the Puppet Language.
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
  # Default value assignment is handled by using the regular Ruby mechanism (a value is assigned to the variable).
  # The dispatch simply indicates that the value is optional. If the default value should be injected, it can be
  # handled different ways depending on what is desired:
  #
  # * by calling the accessor method for an injected Function class attribute. This is suitable if the
  #   value is constant across all instantiations of the function, and across all calls.
  # * by injecting a parameter into the call to the left of the parameter, and then assigning that as the default value.
  # * One of the above forms, but using an injected producer instead of a directly injected value.
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
  # Access to Scope
  # ---
  # In general, functions should not need access to scope; they should be written to act on their given input
  # only. If they absolutely must look up variable values, they should do so via the closure scope (the scope where they
  # are defined) - this is done by calling `closure_scope()`.
  #
  # For Puppet System Functions where access to the calling scope may be essential the implementor of the function may
  # override the `Function.call` method to pass the scope on to the method(s) implementing the body of the function.
  #
  # Calling other Functions
  # ---
  # Calling other functions by name is directly supported via `call_funcion(name, *args)`. This allows a function
  # to call other functions visible from its loader.
  #
  # @todo Optimizations
  #
  #   Unoptimized implementation. The delegation chain is longer than required, and arguments are passed with splat.
  #   The chain Function -> class -> Dispatcher -> Dispatch -> Visitor can be shortened for non polymorph dispatching.
  #   Also, when there is only one signature (single Dispatch), a different Dispatcher could short circuit the search.
  #
  # @param func_name [String, Symbol] a simple or qualified function name
  # @param &block [Proc] the block that defines the methods and dispatch of the Function to create
  # @return [Class<Function>] the newly created Function class
  #
  def self.create_function(func_name, &block)
    func_name = func_name.to_s
    # Creates an anonymous class to represent the function
    # The idea being that it is garbage collected when there are no more
    # references to it.
    #
    the_class = Class.new(Function, &block)

    # Make the anonymous class appear to have the class-name <func_name>
    # Even if this class is not bound to such a symbol in a global ruby scope and
    # must be resolved via the loader.
    # This also overrides any attempt to define a name method in the given block
    # (Since it redefines it)
    #
    # TODO, enforce name in lower case (to further make it stand out since Ruby class names are upper case)
    #
    the_class.instance_eval do
      @func_name = func_name
      def name
        @func_name
      end
    end

    # Automatically create an object dispatcher based on introspection if the loaded user code did not
    # define any dispatchers. Fail if function name does not match a given method name in user code.
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
  def self.default_dispatcher(the_class, func_name)
    unless the_class.method_defined?(func_name)
      raise ArgumentError, "Function Creation Error, cannot create a default dispatcher for function '#{func_name}', no method with this name found"
    end
    object_signature(*min_max_param(the_class.instance_method(func_name)))
  end

  def self.min_max_param(method)
    # Ruby 1.8.7 does not have support for details about parameters
    if method.respond_to?(:parameters)
      result = {:req => 0, :opt => 0, :rest => 0 }
      # TODO: Optimize into one map iteration that produces names map, and sets count as side effect
      method.parameters.each { |p| result[p[0]] += 1 }
      from = result[:req]
      to = result[:rest] > 0 ? :default : from + result[:opt]
      names = method.parameters.map {|p| p[1].to_s }
    else
      # Cannot correctly compute the signature in Ruby 1.8.7 because arity for optional values is
      # screwed up (there is no way to get the upper limit), an optional looks the same as a varargs
      # In this case - the failure will simply come later when the call fails
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
  def self.object_signature(from, to, names)
    # Construct the type for the signature
    # Tuple[Object, from, to]
    factory = Puppet::Pops::Types::TypeFactory
    [factory.callable(factory.object, from, to), names]
  end

  # Function
  # ===
  # This class is the base class for all Puppet 4x Function API functions. A specialized class is
  # created for each puppet function.
  # Most methods act on the class, except `call`, `closure_scope`, and `loader` which are bound to a
  # particular instance of the function (it is aware of its runtime context).
  #
  class Function
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
    def call(scope, *args)
      self.class.dispatcher.dispatch(self, scope, args)
    end

    # Allows the implementation of a function to call other functions by name. The callable functions
    # are those visible to the same loader that loaded this function (the calling function).
    #
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

    def self.define_dispatch(&block)
      builder = DispatcherBuilder.new(dispatcher)
      builder.instance_eval &block
    end

    def self.dispatch(meth_name, &block)
      builder = DispatcherBuilder.new(dispatcher)
      builder.instance_eval do
        dispatch(meth_name, &block)
      end
    end

    def self.dispatch_polymorph(meth_name, &block)
      builder = DispatcherBuilder.new(dispatcher)
      builder.instance_eval do
        dispatch_polymorph(meth_name, &block)
      end
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

    def self.dispatcher
      @dispatcher ||= Puppet::Pops::Functions::Dispatcher.new
    end

    # Delegates method calls not supported by Function.class to the TypeFactory
    #
    def self.method_missing(meth, *args, &block)
      if Puppet::Pops::Types::TypeFactory.respond_to?(meth)
        Puppet::Pops::Types::TypeFactory.send(meth, *args, &block)
      else
        super
      end
    end

    def self.respond_to?(meth, include_all=false)
      Puppet::Pops::Types::TypeFactory.respond_to?(meth, include_all) || super
    end

    # Produces information about parameters in a way that is compatible with Closure
    #
    def self.signatures
      @dispatcher.signatures
    end
  end

  class DispatcherBuilder
    def initialize(dispatcher)
      @dispatcher = dispatcher
    end

    # Delegates method calls not supported by Function.class to the TypeFactory
    #
    def method_missing(meth, *args, &block)
      if Puppet::Pops::Types::TypeFactory.respond_to?(meth)
        Puppet::Pops::Types::TypeFactory.send(meth, *args, &block)
      else
        super
      end
    end

    def respond_to?(meth, include_all=false)
      Puppet::Pops::Types::TypeFactory.respond_to?(meth, include_all) || super
    end

    def dispatch(meth_name, &block)
      # an array of either an index into names/types, or an array with injection information [type, name, injection_name]
      # used when the call is being made to weave injections into the given arguments.
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
      callable_t = self.class.create_callable(@types, @block_type, @min, @max)
      @dispatcher.add_dispatch(callable_t, meth_name, @names, @block_name, @injections, @weaving, @last_captures)
    end

    def dispatch_polymorph(meth_name, &block)
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
      callable_t = self.class.create_callable(@types, @block_type, @min, @max)
      @dispatcher.add_polymorph_dispatch(callable_t, meth_name, @names, @block_name, @injections, @weaving, @last_captures)
    end

    # Defines one parameter with type and name
    def param(type, name)
      @types << type
      @names << name
      # mark what should be picked for this position when dispatching
      @weaving << @names.size()-1
    end

    # Defines one required block parameter that may appear last. If type or name is missing the
    # defaults are "any callable", and the name is "block"
    #
    def required_block_param(*type_and_name)
      case type_and_name.size
      when 0
        type = all_callables()
        name = 'block'
      when 1
        x = type_and_name[0]
        if x.is_a?(Puppet::Pops::Types::PCallableType)
          type = x
          name = 'block'
        else
          unless x.is_a?(String) || x.is_a?(Symbol)
            raise ArgumentError, "Expected block_param name to be a String, got #{x.class}"
          end
          type = all_callables()
          name = x.to_s()
        end
      when 2
        type, name = type_and_name
      else
        raise ArgumentError, "block_param accepts max 2 arguments (type, name), got #{type_and_name.size}."
      end

      unless type.is_a?(Puppet::Pops::Types::PCallableType)
        raise ArgumentError, "Expected PCallableType, got #{type.class}"
      end

      unless name.is_a?(String)
        raise ArgumentError, "Expected block_param name to be a String, got #{name.class}"
      end

      unless @block_type.nil?
        raise ArgumentError, "Attempt to redefine block"
      end
      @block_type = type
      @block_name = name
    end

    # Defines one optional block parameter that may appear last. If type or name is missing the
    # defaults are "any callable", and the name is "block". The implementor of the dispatch target
    # must use block = nil when it is optional (or an error is raised when the call is made).
    #
    def optional_block_param(*type_and_name)
      # same as required, only wrap the result in an optional type
      required_block_param(*type_and_name)
      @block_type = optional(@block_type)
    end

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

    # Specifies the min and max occurance of arguments (of the specified types) if something other than
    # the exact count from the number of specified types). The max value may be specified as -1 if an infinite
    # number of arguments are supported. When max is > than the number of specified types, the last specified type
    # repeats.
    #
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
    def last_captures_rest
      @last_captures = true
    end

    # Handles creation of a callable type from strings, puppet types, or ruby types and allows
    # the min/max occurs of the given types to be given as one or two integer values at the end.
    # The given block_type should be Optional[Callable], Callable, or nil.
    #
    def self.create_callable(types, block_type, from, to)
      mapped_types = types.map do |t|
        case t
        when String
          type_parser ||= Puppet::Pops::Types::TypeParser.new
          type_parser.parse(t)
        when Puppet::Pops::Types::PAbstractType
          t
        when Class
          Puppet::Pops::Types::TypeFactory.type_of(t)
        else
          raise ArgumentError, "Type signature argument must be a Puppet Type, Class, or a String reference to a type. Got #{t.class}"
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
end
