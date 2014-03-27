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
  # It is possible to inject and weave parameters into a call. These extra parameters are not passed from the
  # Puppet logic.
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
  # The function in the example above is called like this:
  #
  #     test(10, 20)
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

    # TODO: The func_name should be a symbol - else error
    # Why symbol? They are sticky in memory and the qualified name used in PP is a Fully qualified string
    # It should probably be either a QualifiedName (counting on it to already be validated? or check again? or
    # a string
    # Assume String for now, and that names are properly formed...
    # Later, must handle name spacing of function, and only use last part as the actual name - better with two
    # parameters, namespace, and func_name perhaps - or maybe namespace is derived from where it is found, which is
    # even better
    #

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
      the_class.dispatcher.add_dispatch(type, simple_name, names, nil, nil)
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
      names = method.parameters.map {|p| p[1] }
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

  def self.object_signature(from, to, names)
    # Construct the type for the signature
    # Array[Object], Integer[from, to]]
    factory = Puppet::Pops::Types::TypeFactory
    optional_object = factory.object
    [factory.constrain_size(factory.array_of(optional_object), from, to), names]
  end

  class Function
    # The scope where the function is defined
    attr_reader :closure_scope

    # The loader that loaded this function
    # Should be used if function wants to load other things.
    #
    attr_reader :loader

    def initialize(closure_scope, loader)
      @closure_scope = closure_scope
      @loader = loader
    end

    def call(scope, *args)
      self.class.dispatcher.dispatch(self, scope, args)
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
      @dispatcher ||= Dispatcher.new
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
      self.instance_eval &block
      @dispatcher.add_dispatch(self.class.create_tuple(@types, @min, @max), meth_name, @names, @injections, @weaving)
    end

    def dispatch_polymorph(meth_name, &block)
      @types = []
      @names = []
      @weaving = []
      @injections = []
      @min = nil
      @max = nil
      self.instance_eval &block
      @dispatcher.add_polymorph_dispatch(self.class.create_tuple(@types, @min, @max), meth_name, @names, @injections, @weaving)
    end

    def param(type, name)
      @types << type
      @names << name
      # mark what should be picked for this position when dispatching
      @weaving << @names.size()-1
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

    # Handles creation of a tuple type from strings, puppet types, or ruby types and allows
    # the min/max occurs of the given types to be given as one or two integer values at the end.
    #
    def self.create_tuple(types, from, to)
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
      tuple_t = Puppet::Pops::Types::TypeFactory.tuple(*mapped_types)
      if !(from.nil? && to.nil?)
        Puppet::Pops::Types::TypeFactory.constrain_size(tuple_t, from,to)
      else
        tuple_t
      end
    end
  end

  # This is a smart dispatcher
  # For backwards compatible (untyped) API, the dispatcher only enforces simple count, and can be simpler internally
  #
  class Dispatcher
    attr_reader :dispatchers

    def initialize()
      @dispatchers = [ ]
    end

    # Answers if dispatching has been defined
    # @return [Boolean] true if dispatching has been defined
    #
    def empty?
      @dispatchers.empty?
    end

    # Dispatches the call to the first found signature (entry with matching type).
    #
    # @param instance [Puppet::Functions::Function] - the function to call
    # @param calling_scope [T.B.D::Scope] - the scope of the caller
    # @param args [Array<Object>] - the given arguments in the form of an Array
    # @return [Object] - what the called function produced
    #
    def dispatch(instance, calling_scope, args)
      tc = Puppet::Pops::Types::TypeCalculator
      actual = tc.infer_set(args)
      found = @dispatchers.find { |d| tc.assignable?(d.type, actual) }
      if found
        found.invoke(instance, calling_scope, args)
      else
        raise ArgumentError, "function '#{instance.class.name}' called with mis-matched arguments\n#{diff_string(instance.class.name, actual)}"
      end
    end

    # Adds a regular dispatch for one method name
    #
    # @param type [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] - type describing signature
    # @param method_name [String] - the name of the method that will be called when type matches given arguments
    # @param names [Array<String>] - array with names matching the number of parameters specified by type (or empty array)
    #
    def add_dispatch(type, method_name, param_names, injections, weaving)
      @dispatchers << Dispatch.new(type, NonPolymorphicVisitor.new(method_name), param_names, injections, weaving)
    end

    # Adds a polymorph dispatch for one method name
    #
    # @param type [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] - type describing signature
    # @param method_name [String] - the name of the (polymorph) method that will be called when type matches given arguments
    # @param names [Array<String>] - array with names matching the number of parameters specified by type (or empty array)
    #
    def add_polymorph_dispatch(type, method_name, param_names, injections, weaving)
      # Type is a CollectionType, its size-type indicates min/max args
      # This includes the polymorph object which needs to be deducted from the
      # number of additional args
      # NOTE: the type is valuable if there are type constraints also on the first arg
      # (better error message)
      range = type.size_range # get .from, .to, unbound if nil (from must be bound, to can be nil)
      raise ArgumentError, "polymorph dispath on collection type without range" unless range
      raise ArgumentError, "polymorph dispatch on signature without object" if range[0] < 1
      from = range[0] - 1 # The object itself is not included
      to = range[1] -1 # object not included here either (it may be infinity, but does not matter)
      if !injections.empty?
        from += injections.size
        to += injections.size
      end
      to = (to == Puppet::Pops::Types::INFINITY) ? -1 : to
      @dispatchers << Dispatch.new(type, Puppet::Pops::Visitor.new(self, method_name, from, to), param_names, injections, weaving)
      # @dispatchers << [ type, Puppet::Pops::Visitor.new(self, method_name, from, to), param_names, injections, weaving ]
    end

    private

    class Dispatch
      attr_reader :type
      attr_reader :visitor
      attr_reader :param_names
      attr_reader :injections
      attr_reader :weaving

      def initialize(type, visitor, param_names, injections, weaving)
        @type = type
        @visitor = visitor
        @param_names = param_names || []
        @injections = injections || []
        @weaving = weaving
      end

      def invoke(instance, calling_scope, args)
        @visitor.visit_this(instance, *weave(calling_scope, args))
      end

      def weave(scope, args)
        # no nead to weave if there are no injections
        if injections.empty?
          args
        else
          injector = Puppet.lookup(:injector)
          weaving.map do |knit|
            if knit.is_a?(Array)
              injection_data = @injections[knit[0]]
              # inject
              if injection_data[3] == :producer
                injector.lookup_producer(scope, injection_data[0], injection_data[2])
              else
                injector.lookup(scope, injection_data[0], injection_data[2])
              end
            else
              # pick that argument
              args[knit]
            end
          end
        end
      end
    end

    # Produces a string with the difference between the given arguments and support signature(s).
    #
    def diff_string(name, args_type)
      result = [ ]
      if @dispatchers.size < 2
        params_type  = @dispatchers[ 0 ].type
        params_names = @dispatchers[ 0 ].param_names
        result << "expected:\n  #{name}(#{signature_string(params_type, params_names)}) - #{arg_count_string(params_type)}"
      else
        result << "expected one of:\n"
        result << (@dispatchers.map {|d| "  #{name}(#{signature_string(d.type, d.param_names)}) - #{arg_count_string(d.type)}"}.join("\n"))
      end
      result << "\nactual:\n  #{name}(#{arg_types_string(args_type)}) - #{arg_count_string(args_type)}"
      result.join('')
    end

    # Produces a string for the signature(s)
    #
    def signature_string(args_type, param_names)
      size_type = args_type.size_type
      types =
      case args_type
      when Puppet::Pops::Types::PTupleType
        last_range = args_type.repeat_last_range
        required_count, _ = args_type.size_range
        args_type.types
      when Puppet::Pops::Types::PArrayType
        from, to = args_type.size_range
        required_count = from
        # array has just one element, but there may be multiple names that needs to be subtracted from the count
        # to make it correct for the last named element
        adjust = max(0, param_names.size() -1)
        last_range = [max(0, (from - adjust)), (to - adjust)]
        [ args_type.element_type ]
      end
      tc = Puppet::Pops::Types::TypeCalculator

      # join type with names (types are always present, names are optional)
      # separate entries with comma
      #
      if param_names.empty?
        result = types.each_with_index.map {|t, index| tc.string(t) + opt_value_indicator(index, required_count, 0) }.join(', ')
      else
        limit = param_names.size
        result = param_names.each_with_index.map do |name, index|
          [tc.string(types[index] || types[-1]), name].join(' ') + opt_value_indicator(index, required_count, limit)
        end.join(', ')
      end

      # Add {from, to} for the last type
      # This works for both Array and Tuple since it describes the allowed count of the "last" type element
      # for both. It does not show anything when the range is {1,1}.
      #
      result += range_string(last_range)
      result
    end

    # Why oh why Ruby do you not have a standard Math.max ?
    def max(a, b)
      a >= b ? a : b
    end

    def opt_value_indicator(index, required_count, limit)
      count = index + 1
      (count > required_count && count < limit) ? '?' : ''
    end

    def arg_count_string(args_type)
      "arg count #{range_string(args_type.size_range, false)}"
    end

    def arg_types_string(args_type)
      types =
      case args_type
      when Puppet::Pops::Types::PTupleType
        last_range = args_type.repeat_last_range
        args_type.types
      when Puppet::Pops::Types::PArrayType
        last_range = args_type.size_range
        [ args_type.element_type ]
      end
      # stringify generalized versions or it will display Integer[10,10] for "10", String['the content'] etc.
      # note that type must be copied since generalize is a mutating operation
      tc = Puppet::Pops::Types::TypeCalculator
      result = types.map { |t| tc.string(tc.generalize!(t.copy)) }.join(', ')

      # Add {from, to} for the last type
      # This works for both Array and Tuple since it describes the allowed count of the "last" type element
      # for both. It does not show anything when the range is {1,1}.
      #
      result += range_string(last_range)
      result
    end

    # Formats a range into a string {from, to} with optimizations when:
    # * from and to are equal => {from}
    # * from and to are both and 1 and squelch_one == true => ''
    # * from is 0 and to is 1 => '?'
    # * to is INFINITY => {from, }
    #
    def range_string(size_range, squelch_one = true)
      from = size_range[ 0 ]
      to = size_range[ 1 ]
      if from == to
        (squelch_one && from == 1) ? '' : "{#{from}}"
      elsif to == Puppet::Pops::Types::INFINITY
        "{#{from},}"
      elsif from == 0 && to == 1
        '?'
      else
        "{#{from},#{to}}"
      end
    end

  end

  # Simple non Polymorphic Visitor
  class NonPolymorphicVisitor
    attr_reader :name
    def initialize(name)
      @name = name
    end

    def visit_this(instance, *args)
      instance.send(name, *args)
    end
  end
end