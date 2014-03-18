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
  # The simplest form of defining a function introspects the method signature (in the example `min(a,b)` and
  # infers that this means that there are 2 required arguments of Object type. If something else is wanted
  # the method define_dispatch should be called in the block defining the function.
  # In the next example, the function is enhanced to check that arguments are of numeric type.
  #
  # @example dispatch and type checking
  #   Puppet::Functions.create_function('min') do
  #     define_dispatch do
  #       dispatch('min', Numeric, Numeric)
  #     end
  #     def min(a, b)
  #       a <= b ? a : b
  #     end
  #   end
  #
  # It is possible to specify multiple type signatures, and dispatch to the same, or alternative methods.
  # When a call is processed the given type signatures are tested in the order they were defined - the first signature
  # with matching type wins.
  #
  # The dispatcher also supports polymorphic dispatch where the method to call is selected based on the type of the
  # first argument. It is possible to mix non/polymorphic dispatching, the first with a matching signature wins
  # in all cases. (Typically one or the other dispatch type is selected for a given function).
  # Polymorphic dispatch are based on a method prefix, followed by "_ClassName" where "ClassName" is the simple name
  # of the class of the first argument.
  #
  # @example using polymorphic dispatch
  #   Puppet::Functions.create_function('label') do
  #     define_dispatch do
  #       dispatch_polymorph('label', Object)
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
  # The type specification of the signature that follows the name of the method are given to the Puppet::Pops::Types::TypeFactory
  # to create a PTupleType.
  # Arguments may be Puppet Type References in String form, Ruby classes (for basic types), or Puppet Type instances
  # as created by the Puppet::Pops::Types::TypeFactory. To make type creation convenient, the logic that builds a dispatcher
  # redirects any calls to the type factory.
  # 
  def self.create_function(func_name, &block)

    # Create an anonymous class to represent the function
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
    # TODO, the final name of the function class should also reflect the name space
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
      the_class.dispatcher.add_dispatch(default_dispatcher(the_class, func_name), func_name)
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
      method.parameters.each { |p| result[p[0]] += 1 }
      min = result[:req]
      max = result[:rest] > 0 ? :default : min + result[:opt]
    else
      # Cannot correctly compute the signature in Ruby 1.8.7 because arity for optional values is
      # screwed up (there is no way to get the upper limit), an optional looks the same as a varargs
      # In this case - the failure will simply come later when the call fails
      #
      arity = m.arity
      min = arity >= 0 ? arity : -arity -1
      max = arity >= 0 ? arity : :default  # i.e. infinite (which is wrong when there are optional - flaw in 1.8.7)
    end
    [min, max]
  end

  def self.object_signature(min, max)
    # Construct the type for the signature
    # Array[Optional[Object], Integer[min, max]]
    factory = Puppet::Pops::Types::TypeFactory
    optional_object = factory.optional(factory.object)
    factory.constrain_size(factory.array_of(optional_object), min, max)
  end

  class Function
    attr_reader :call_scope

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
      @call_scope = scope
      self.class.dispatcher.dispatch(self, args)
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
      @types = []
      @names = []
      @min = nil
      @max = nil
      self.instance_eval &block

      # fixup what param method recorded to make it compatible with dispatch_on_type
      # (i.e. the last two parameters may be integers, and define min (and optionally) max occurrence of last type).
      #
      @types << @min unless @min.nil?
      @types << @max unless @max.nil?
      @dispatcher.add_dispatch(self.class.create_tuple(@types), meth_name, @names)
    end

    def dispatch_polymorph(meth_name, &block)
      @types = []
      @names = []
      @min = nil
      @max = nil
      self.instance_eval &block
      # fixup what param method recorded to make it compatible with dispatch_on_type
      # (i.e. the last two parameters may be integers, and define min (and optionally) max occurrence of last type).
      #
      @types << @min unless @min.nil?
      @types << @max unless @max.nil?
      @dispatcher.add_polymorph_dispatch(self.class.create_tuple(@types), meth_name, @names)
    end

    def param(type, name, min_occurs = nil, max_occurs = nil)
      @types << type
      @names << name
      # only the last parameter may have min, max occurrence set - this test ensures this
      if !@min.nil?
        raise ArgumentError, "attempt to define parameter '#{name}'  after variable occurences set for previous param"
      end
      @min = min_occurs
      @max = max_occurs
      unless min_occurs.nil? || min_occurs.is_a?(Integer)
        raise ArgumentError, "min occurrence of function parameter must be an Integer, got #{min_occurs.class}"
      end
      unless max_occurs.nil? || max_occurs.is_a?(Integer)
        raise ArgumentError, "max occurrence of function parameter must be an Integer, got #{max_occurs.class}"
      end
    end

    def dispatch_on_type(meth_name, *tuple_signature)
      @dispatcher.add_dispatch(meth_name, self.class.create_tuple(tuple_signature),[])
    end

    def dispatch_polymorph_on_type(meth_name, *tuple_signature)
      @dispatcher.add_polymorph_dispatch(meth_name, self.class.create_tuple(tuple_signature), [])
    end

    # Handles creation of a tuple type from strings, puppet types, or ruby types and allows
    # the min/max occurs of the last given type to be given as one or two integer values at the end.
    def self.create_tuple(tuple_args_array)
      size_constraint = nil

      # Check if size multiplicity of last type was specified and adjust
      # arguments. Multiplicity may be a single (min occurs), or two (min, max occurs) Integer values.
      # An upper 'unbound' is created if only min occurs is specified.
      # If neither min nor max occurs is given, the tuple is fixed at the given types.
      #
      if tuple_args_array[ -1 ].is_a?(Integer)
        if tuple_args_array[ -2 ].is_a?(Integer)
          types = tuple_args_array[ 0..-2 ]
          size_constraint = tuple_args_array.slice(-2,2)
        else
          types = tuple_args_array.slice(0..-2)
          size_constraint = tuple_args_array.slice(-2,2)
        end
      else
        types = tuple_args_array
      end

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
          raise ArgumentError, "Type signature argument must be a Puppet Type, or a String reference to a type. Got #{t.class}"
        end
      end
      tuple_t = Puppet::Pops::Types::TypeFactory.tuple(*mapped_types)
      if size_constraint
        Puppet::Pops::Types::TypeFactory.constrain_size(tuple_t, size_constraint)
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
    # @param args [Array<Object>] - the given arguments in the form of an Array
    # @return [Object] - what the called function produced
    #
    def dispatch(instance, args)
      tc = Puppet::Pops::Types::TypeCalculator
      actual = tc.infer_set(args)
      found = @dispatchers.find { |d| tc.assignable?(d[ 0 ], actual) }
      if found
        found[ 1 ].visit_this(instance, *args)
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
    def add_dispatch(type, method_name, param_names=[])
      @dispatchers << [ type, NonPolymorphicVisitor.new(method_name), param_names ]
    end

    # Adds a polymorph dispatch for one method name
    #
    # @param type [Puppet::Pops::Types::PArrayType, Puppet::Pops::Types::PTupleType] - type describing signature
    # @param method_name [String] - the name of the (polymorph) method that will be called when type matches given arguments
    # @param names [Array<String>] - array with names matching the number of parameters specified by type (or empty array)
    #
    def add_polymorph_dispatch(type, method_name, param_names=[])
      # Type is a CollectionType, its size-type indicates min/max args
      # This includes the polymorph object which needs to be deducted from the
      # number of additional args
      # NOTE: the type is valuable if there are type constraints also on the first arg
      # (better error message)
      range = type.size_type # get .from, .to, unbound if nil (from must be bound, to can be nil)
      raise ArgumentError, "polymorph dispath on collection type without range" unless range
      raise ArgumentError, "polymorph dispatch on signature without object" if range.from.nil? || range.from < 1
      min = range.from - 1
      max = range.to.nil? ? -1 : (range.to - 1)
      @dispatchers << [ type, Puppet::Pops::Visitor.new(self, method_name, min, max), param_names ]
    end

    private

    # Produces a string with the difference between the given arguments and support signature(s).
    #
    def diff_string(name, args_type)
      result = [ ]
      if @dispatchers.size < 2
        params_type  = @dispatchers[ 0 ][ 0 ]
        params_names = @dispatchers[ 0 ][ 2 ]
        result << "expected:\n  #{name}(#{signature_string(params_type, params_names)}) - #{arg_count_string(params_type)}"
      else
        result << "expected one of:\n"
        result += @dispatchers.map { |d| "#{name}(#{signature_string(d[0], d[2])}) - #{arg_count_string(d[0])}" }.join('\n  ')
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
        args_type.types
      when Puppet::Pops::Types::PArrayType
        last_range = args_type.size_range
        [ args_type.element_type ]
      end
      tc = Puppet::Pops::Types::TypeCalculator

      # join type with names (types are always present, names are optional)
      # separate entries with comma
      #
      result = types.zip(param_names).map { |t| [tc.string(t[0]), t[1]].compact.join(' ') }.join(', ')

      # Add {from, to} for the last type
      # This works for both Array and Tuple since it describes the allowed count of the "last" type element
      # for both. It does not show anything when the range is {1,1}.
      #
      result += range_string(last_range)
      result
    end

    def arg_count_string(args_type)
      "arg count #{range_string(args_type.size_range, false)}"
    end

    # TODO: CHANGE to print func(arg, arg, arg) - arg count n
    # Count is always the from size of the type since it is an actual count
    #
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

    def range_string(size_range, squelch_one = true)
      from = size_range[ 0 ]
      to = size_range[ 1 ]
      if from == to
        (squelch_one && from == 1) ? '' : "{#{from}}"
      elsif to == Puppet::Pops::Types::INFINITY
        "{#{from},}"
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