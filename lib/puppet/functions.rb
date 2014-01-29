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
    m = the_class.instance_method(func_name)
    unless m
      raise ArgumentError, "Cannot create a default dispatcher for function #{func_name}, no method with the same name found"
    end
    object_signature(*min_max_param(m))
  end

  def self.min_max_param(method)
    # Ruby 1.8.7 does not have support for details about parameters
    if m.respond_to?(:parameters)
      result = {:req => 0, :opt => 0, :rest => 0 }
      m.parameters.each { |p| result[p[0]] += 1 }
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
    constrain_size(factory.array_of(optional_object), min, max)
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
      @dispatcher.dispatch(self, args)
    end

    def self.define_dispatch(&block)
      builder = DispatcherBuilder.new(dispatcher)
      builder.instance_eval &block
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

    def dispatch(meth_name, *tuple_signature)
      @dispatcher.add_dispatch(meth_name, create_tuple(tuple_signature))
    end

    def dispatch_polymorph(meth_name, *tuple_signature)
      @dispatcher.add_polymorph_dispatch(meth_name, @signature)
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
      if tuple_args_array[-1].is_a?(Integer)
        if tuple_args_array[-2].is_a?(Integer)
          types = tuple_args_array.slice[0..-2]
          size_constraint = tuple_args_array.slice(-2,2)
        else
          types = tuple_args_array.slice[0..-2]
          size_constraint = tuple_args_array.slice(-2,2)
        end
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
      tuple_t = Puppet::Pops::Types::TypeFactory.tuple(mapped_types)
      if size_constraint
        Puppet::Pops::Types::TypeFactory.constrain_size(tuple_t, size_constraint)
      else
        tuple_t
      end
    end

  # This is a smart dispatcher
  # For backwards compatible (untyped) API, the dispatcher only enforces simple count, and can be simpler internally
  #
  class Dispatcher

    def initialize()
      @dispatchers = []
    end

    def empty?
      @dispatchers.empty?
    end

    def dispatch(instance, args)
      tc = Puppet::Pops::Types::TypeCalculator
      actual = tc.infer_set(args)
      found = @dispatchers.find { |d| tc.assignable?(d[0], actual) }
      if found
        found[1].visit_this(instance, *args)
      else
        raise ArgumentError, "no method with matching signature found"  # TODO: TO BE IMPROVED
      end
    end

    def add_dispatch(type, func_name)
      @dispatchers << [type, NonPolymorphicVisitor.new(func_name)]
    end

    def add_polymorph_dispatch(type, method_name)
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
      @dispatchers << [ type, Puppet::Pops::Visitor.new(self, method_name, min, max)]
    end

  end

  # Simple non Polymorphic Visitor
  class NonPolymorphicVisitor
    def initialize(name)
      @name = name
    end

    def visit_this(instance, *args)
      instance.send(name, *args)
    end
  end
end