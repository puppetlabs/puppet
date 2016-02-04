module Puppet::Pops
module Binder
# A helper class that makes it easier to construct a Bindings model.
#
# The Bindings Model
# ------------------
# The BindingsModel (defined in {Bindings} is a model that is intended to be generally free from Ruby concerns.
# This means that it is possible for system integrators to create and serialize such models using other technologies than
# Ruby. This manifests itself in the model in that producers are described using instances of a `ProducerDescriptor` rather than
# describing Ruby classes directly. This is also true of the type system where type is expressed using the {Types} model
# to describe all types.
#
# This class, the `BindingsFactory` is a concrete Ruby API for constructing instances of classes in the model.
#
# Named Bindings
# --------------
# The typical usage of the factory is to call {named_bindings} which creates a container of bindings wrapped in a *build object*
# equipped with convenience methods to define the details of the just created named bindings.
# The returned builder is an instance of {BindingsFactory::BindingsContainerBuilder BindingsContainerBuilder}.
#
# Binding
# -------
# A Binding binds a type/name key to a producer of a value. A binding is conveniently created by calling `bind` on a
# `BindingsContainerBuilder`. The call to bind, produces a binding wrapped in a build object equipped with convenience methods
# to define the details of the just created binding. The returned builder is an instance of
# {BindingsFactory::BindingsBuilder BindingsBuilder}.
#
# Multibinding
# ------------
# A multibinding works like a binding, but it requires an additional ID. It also places constraints on the type of the binding;
# it must be a collection type (Hash or Array).
#
# Constructing and Contributing Bindings from Ruby
# ------------------------------------------------
# The bindings system is used by referencing bindings symbolically; these are then specified in a Ruby file which is autoloaded
# by Puppet. The entry point for user code that creates bindings is described in {Puppet::Bindings Bindings}.
# That class makes use of a BindingsFactory, and the builder objects to make it easy to construct bindings.
#
# It is intended that a user defining bindings in Ruby should be able to use the builder object methods for the majority of tasks.
# If something advanced is wanted, use of one of the helper class methods on the BuildingsFactory, and/or the
# {Types::TypeCalculator TypeCalculator} will be required to create and configure objects that are not handled by
# the methods in the builder objects.
#
# Chaining of calls
# ------------------
# Since all the build methods return the build object it is easy to stack on additional calls. The intention is to
# do this in an order that is readable from left to right: `bind.string.name('thename').to(42)`, but there is nothing preventing
# making the calls in some other order e.g. `bind.to(42).name('thename').string`, the second is quite unreadable but produces
# the same result.
#
# For sake of human readability, the method `name` is alsp available as `named`, with the intention that it is used after a type,
# e.g. `bind.integer.named('the meaning of life').to(42)`
#
# Methods taking blocks
# ----------------------
# Several methods take an optional block. The block evaluates with the builder object as `self`. This means that there is no
# need to chain the methods calls, they can instead be made in sequence - e.g.
#
#     bind do
#       integer
#       named 'the meaning of life'
#       to 42
#     end
#
# or mix the two styles
#
#     bind do
#       integer.named 'the meaning of life'
#       to 42
#     end
#
# Unwrapping the result
# ---------------------
# The result from all methods is a builder object. Call the method `model` to unwrap the constructed bindings model object.
#
#     bindings = BindingsFactory.named_bindings('my named bindings') do
#       # bind things
#     end.model
#
# @example Create a NamedBinding with content
#   result = BindingsFactory.named_bindings("mymodule::mybindings") do
#     bind.name("foo").to(42)
#     bind.string.name("site url").to("http://www.example.com")
#   end
#   result.model()
#
# @api public
#
module BindingsFactory

  # Alias for the {Types::TypeFactory TypeFactory}. This is also available as the method
  # `type_factory`.
  #
  T = Types::TypeFactory

  # Abstract base class for bindings object builders.
  # Supports delegation of method calls to the BindingsFactory class methods for all methods not implemented
  # by a concrete builder.
  #
  # @abstract
  #
  class AbstractBuilder
    # The built model object.
    attr_reader :model

    # @param binding [Bindings::AbstractBinding] The binding to build.
    # @api public
    def initialize(binding)
      @model = binding
    end

    # Provides convenient access to the Bindings Factory class methods. The intent is to provide access to the
    # methods that return producers for the purpose of composing more elaborate things than the builder convenience
    # methods support directly.
    # @api private
    #
    def method_missing(meth, *args, &block)
      factory = BindingsFactory
      if factory.respond_to?(meth)
        factory.send(meth, *args, &block)
      else
        super
      end
    end
  end

  # A bindings builder for an AbstractBinding containing other AbstractBinding instances.
  # @api public
  class BindingsContainerBuilder < AbstractBuilder

    # Adds an empty binding to the container, and returns a builder for it for further detailing.
    # An optional block may be given which is evaluated using `instance_eval`.
    # @return [BindingsBuilder] the builder for the created binding
    # @api public
    #
    def bind(&block)
      binding = Bindings::Binding.new()
      model.addBindings(binding)
      builder = BindingsBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end

    # Binds a multibind with the given identity where later, the looked up result contains all
    # contributions to this key. An optional block may be given which is evaluated using `instance_eval`.
    # @param id [String] the multibind's id used when adding contributions
    # @return [MultibindingsBuilder] the builder for the created multibinding
    # @api public
    #
    def multibind(id, &block)
      binding = Bindings::Multibinding.new()
      binding.id = id
      model.addBindings(binding)
      builder = MultibindingsBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end
  end

  # Builds a Binding via convenience methods.
  #
  # @api public
  #
  class BindingsBuilder < AbstractBuilder

    # @param binding [Bindings::AbstractBinding] the binding to build.
    # @api public
    def initialize(binding)
      super binding
      data()
    end

    # Sets the name of the binding.
    # @param name [String] the name to bind.
    # @api public
    def name(name)
      model.name = name
      self
    end

    # Same as {#name}, but reads better in certain combinations.
    # @api public
    alias_method :named, :name

    # Sets the binding to be abstract (it must be overridden)
    # @api public
    def abstract
      model.abstract = true
      self
    end

    # Sets the binding to be override (it must override something)
    # @api public
    def override
      model.override = true
      self
    end

    # Sets the binding to be final (it may not be overridden)
    # @api public
    def final
      model.final = true
      self
    end

    # Makes the binding a multibind contribution to the given multibind id
    # @param id [String] the multibind id to contribute this binding to
    # @api public
    def in_multibind(id)
      model.multibind_id = id
      self
    end

    # Sets the type of the binding to the given type.
    # @note
    #   This is only needed if something other than the default type `Data` is wanted, or if the wanted type is
    #   not provided by one of the convenience methods {#array_of_data}, {#boolean}, {#float}, {#hash_of_data},
    #   {#integer}, {#scalar}, {#pattern}, {#string}, or one of the collection methods {#array_of}, or {#hash_of}.
    #
    # To create a type, use the method {#type_factory}, to obtain the type.
    # @example creating a Hash with Integer key and Array[Integer] element type
    #     tc = type_factory
    #     type(tc.hash(tc.array_of(tc.integer), tc.integer)
    # @param type [Types::PAnyType] the type to set for the binding
    # @api public
    #
    def type(type)
      model.type = type
      self
    end

    # Sets the type of the binding to Integer.
    # @return [Types::PIntegerType] the type
    # @api public
    def integer()
      type(T.integer())
    end

    # Sets the type of the binding to Float.
    # @return [Types::PFloatType] the type
    # @api public
    def float()
      type(T.float())
    end

    # Sets the type of the binding to Boolean.
    # @return [Types::PBooleanType] the type
    # @api public
    def boolean()
      type(T.boolean())
    end

    # Sets the type of the binding to String.
    # @return [Types::PStringType] the type
    # @api public
    def string()
      type(T.string())
    end

    # Sets the type of the binding to Pattern.
    # @return [Types::PRegexpType] the type
    # @api public
    def pattern()
      type(T.pattern())
    end

    # Sets the type of the binding to the abstract type Scalar.
    # @return [Types::PScalarType] the type
    # @api public
    def scalar()
      type(T.scalar())
    end

    # Sets the type of the binding to the abstract type Data.
    # @return [Types::PDataType] the type
    # @api public
    def data()
      type(T.data())
    end

    # Sets the type of the binding to Array[Data].
    # @return [Types::PArrayType] the type
    # @api public
    def array_of_data()
      type(T.array_of_data())
    end

    # Sets the type of the binding to Array[T], where T is given.
    # @param t [Types::PAnyType] the type of the elements of the array
    # @return [Types::PArrayType] the type
    # @api public
    def array_of(t)
      type(T.array_of(t))
    end

    # Sets the type of the binding to Hash[Literal, Data].
    # @return [Types::PHashType] the type
    # @api public
    def hash_of_data()
      type(T.hash_of_data())
    end

    # Sets type of the binding to `Hash[Literal, t]`.
    # To also limit the key type, use {#type} and give it a fully specified
    # hash using {#type_factory} and then `hash_of(value_type, key_type)`.
    # @return [Types::PHashType] the type
    # @api public
    def hash_of(t)
      type(T.hash_of(t))
    end

    # Sets the type of the binding based on the given argument.
    # @overload instance_of(t)
    #   The same as calling {#type} with `t`.
    #   @param t [Types::PAnyType] the type
    # @overload instance_of(o)
    #   Infers the type from the given Ruby object and sets that as the type - i.e. "set the type
    #   of the binding to be that of the given data object".
    #   @param o [Object] the object to infer the type from
    # @overload instance_of(c)
    #   @param c [Class] the Class to base the type on.
    #   Sets the type based on the given ruby class. The result is one of the specific puppet types
    #   if the class can be represented by a specific type, or the open ended PRuntimeType otherwise.
    # @overload instance_of(s)
    #   The same as using a class, but instead of giving a class instance, the class is expressed using its fully
    #   qualified name. This method of specifying the type allows late binding (the class does not have to be loaded
    #   before it can be used in a binding).
    #   @param s [String] the fully qualified classname to base the type on.
    # @return the resulting type
    # @api public
    #
    def instance_of(t)
      type(T.type_of(t))
    end

    # Provides convenient access to the type factory.
    # This is intended to be used when methods taking a type as argument i.e. {#type}, {#array_of}, {#hash_of}, and {#instance_of}.
    # @note
    #   The type factory is also available via the constant {T}.
    # @api public
    def type_factory
      Types::TypeFactory
    end

    # Sets the binding's producer to a singleton producer, if given argument is a value, a literal producer is created for it.
    # To create a producer producing an instance of a class with lazy loading of the class, use {#to_instance}.
    #
    # @overload to(a_literal)
    #   Sets a constant producer in the binding.
    # @overload to(a_class, *args)
    #   Sets an Instantiating producer (producing an instance of the given class)
    # @overload to(a_producer_descriptor)
    #   Sets the producer from the given producer descriptor
    # @return [BindingsBuilder] self
    # @api public
    #
    def to(producer, *args)
      case producer
      when Class
        producer = BindingsFactory.instance_producer(producer.name, *args)
      when Model::Program
        # program is not an expression
        producer = BindingsFactory.evaluating_producer(producer.body)
      when Model::Expression
        producer = BindingsFactory.evaluating_producer(producer)
      when Bindings::ProducerDescriptor
      else
      # If given producer is not a producer, create a literal producer
        producer = BindingsFactory.literal_producer(producer)
      end
      model.producer = producer
      self
    end

    # Sets the binding's producer to a producer of an instance of given class (a String class name, or a Class instance).
    # Use a string class name when lazy loading of the class is wanted.
    #
    # @overload to_instance(class_name, *args)
    #   @param class_name [String] the name of the class to instantiate
    #   @param args [Object] optional arguments to the constructor
    # @overload to_instance(a_class)
    #   @param a_class [Class] the class to instantiate
    #   @param args [Object] optional arguments to the constructor
    #
    def to_instance(type, *args)
      class_name = case type
      when Class
        type.name
      when String
        type
      else
        raise ArgumentError, "to_instance accepts String (a class name), or a Class.*args got: #{type.class}."
      end

      # Help by setting the type - since if an to_instance is bound, the type is know. This avoids having
      # to specify the same thing twice.
      self.instance_of(type)
      model.producer = BindingsFactory.instance_producer(class_name, *args)
    end

    # Sets the binding's producer to a singleton producer
    # @overload to_producer(a_producer)
    #   Sets the producer to an instantiated producer. The resulting model can not be serialized as a consequence as there
    #   is no meta-model describing the specialized producer. Use this only in exceptional cases, or where there is never the
    #   need to serialize the model.
    #   @param a_producer [Producers::Producer] an instantiated producer, not serializeable !
    #
    # @overload to_producer(a_class, *args)
    #   @param a_class [Class] the class to create an instance of
    #   @param args [Object] the arguments to the given class' new
    #
    # @overload to_producer(a_producer_descriptor)
    #   @param a_producer_descriptor [Bindings::ProducerDescriptor] a descriptor
    #      producing Producers::Producer
    #
    # @api public
    #
    def to_producer(producer, *args)
      case producer
      when Class
        producer = BindingsFactory.instance_producer(producer.name, *args)
      when Bindings::ProducerDescriptor
      when Producers::Producer
        # a custom producer instance
        producer = BindingsFactory.literal_producer(producer)
      else
        raise ArgumentError, "Given producer argument is none of a producer descriptor, a class, or a producer"
      end
      metaproducer = BindingsFactory.producer_producer(producer)
      model.producer = metaproducer
      self
    end

    # Sets the binding's producer to a series of producers.
    # Use this when you want to produce a different producer on each request for a producer
    #
    # @overload to_producer(a_producer)
    #   Sets the producer to an instantiated producer. The resulting model can not be serialized as a consequence as there
    #   is no meta-model describing the specialized producer. Use this only in exceptional cases, or where there is never the
    #   need to serialize the model.
    #   @param a_producer [Producers::Producer] an instantiated producer, not serializeable !
    #
    # @overload to_producer(a_class, *args)
    #   @param a_class [Class] the class to create an instance of
    #   @param args [Object] the arguments to the given class' new
    #
    # @overload to_producer(a_producer_descriptor)
    #   @param a_producer_descriptor [Bindings::ProducerDescriptor] a descriptor
    #      producing Producers::Producer
    #
    # @api public
    #
    def to_producer_series(producer, *args)
      case producer
      when Class
        producer = BindingsFactory.instance_producer(producer.name, *args)
      when Bindings::ProducerDescriptor
      when Producers::Producer
        # a custom producer instance
        producer = BindingsFactory.literal_producer(producer)
      else
        raise ArgumentError, "Given producer argument is none of a producer descriptor, a class, or a producer"
      end
      non_caching = Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = producer
      metaproducer = BindingsFactory.producer_producer(non_caching)

      non_caching = Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = metaproducer

      model.producer = non_caching
      self
    end

    # Sets the binding's producer to a "non singleton" producer (each call to produce produces a new instance/copy).
    # @overload to_series_of(a_literal)
    #   a constant producer
    # @overload to_series_of(a_class, *args)
    #   Instantiating producer
    # @overload to_series_of(a_producer_descriptor)
    #   a given producer
    #
    # @api public
    #
    def to_series_of(producer, *args)
      case producer
      when Class
        producer = BindingsFactory.instance_producer(producer.name, *args)
      when Bindings::ProducerDescriptor
      else
      # If given producer is not a producer, create a literal producer
        producer = BindingsFactory.literal_producer(producer)
      end
      non_caching = Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = producer
      model.producer = non_caching
      self
    end

    # Sets the binding's producer to one that performs a lookup of another key
    # @overload to_lookup_of(type, name)
    # @overload to_lookup_of(name)
    # @api public
    #
    def to_lookup_of(type, name=nil)
      unless name
        name = type
        type = Types::TypeFactory.data()
      end
      model.producer = BindingsFactory.lookup_producer(type, name)
      self
    end

    # Sets the binding's producer to a one that performs a lookup of another key and they applies hash lookup on
    # the result.
    #
    # @overload to_lookup_of(type, name)
    # @overload to_lookup_of(name)
    # @api public
    #
    def to_hash_lookup_of(type, name, key)
      model.producer = BindingsFactory.hash_lookup_producer(type, name, key)
      self
    end

    # Sets the binding's producer to one that produces the first found lookup of another key
    # @param list_of_lookups [Array] array of arrays [type name], or just name (implies data)
    # @example
    #   binder.bind().name('foo').to_first_found('fee', 'fum', 'extended-bar')
    #   binder.bind().name('foo').to_first_found(
    #     [T.ruby(ThisClass), 'fee'],
    #     [T.ruby(ThatClass), 'fum'],
    #     'extended-bar')
    # @api public
    #
    def to_first_found(*list_of_lookups)
      producers = list_of_lookups.collect do |entry|
        if entry.is_a?(Array)
          case entry.size
          when 2
            BindingsFactory.lookup_producer(entry[0], entry[1])
          when 1
            BindingsFactory.lookup_producer(Types::TypeFactory.data(), entry[0])
          else
            raise ArgumentError, "Not an array of [type, name], name, or [name]"
          end
        else
          BindingsFactory.lookup_producer(T.data(), entry)
        end
      end
      model.producer = BindingsFactory.first_found_producer(*producers)
      self
    end

    # Sets options to the producer.
    # See the respective producer for the options it supports. All producers supports the option `:transformer`, a
    # puppet or ruby lambda that is evaluated with the produced result as an argument. The ruby lambda gets scope and
    # value as arguments.
    # @note
    #   A Ruby lambda is not cross platform safe. Use a puppet lambda if you want a bindings model that is.
    #
    # @api public
    def producer_options(options)
      options.each do |k, v|
        arg = Bindings::NamedArgument.new()
        arg.name = k.to_s
        arg.value = v
        model.addProducer_args(arg)
      end
      self
    end
  end

  # A builder specialized for multibind - checks that type is Array or Hash based. A new builder sets the
  # multibinding to be of type Hash[Data].
  #
  # @api public
  class MultibindingsBuilder < BindingsBuilder
    # Constraints type to be one of {Types::PArrayType PArrayType}, or {Types::PHashType PHashType}.
    # @raise [ArgumentError] if type constraint is not met.
    # @api public
    def type(type)
      unless type.class == Types::PArrayType || type.class == Types::PHashType
        raise ArgumentError, "Wrong type; only PArrayType, or PHashType allowed, got '#{type.to_s}'"
      end
      model.type = type
      self
    end

    # Overrides the default implementation that will raise an exception as a multibind requires a hash type.
    # Thus, if nothing else is requested, a multibind will be configured as Hash[Data].
    #
    def data()
      hash_of_data()
    end
  end

  # Produces a ContributedBindings.
  # A ContributedBindings is used by bindings providers to return a set of named bindings.
  #
  # @param name [String] the name of the contributed bindings (for human use in messages/logs only)
  # @param named_bindings [Bindings::NamedBindings, Array<Bindings::NamedBindings>] the
  #   named bindings to include
  #
  def self.contributed_bindings(name, named_bindings)
    cb = Bindings::ContributedBindings.new()
    cb.name = name
    named_bindings = [named_bindings] unless named_bindings.is_a?(Array)
    named_bindings.each {|b| cb.addBindings(b) }
    cb
  end

  # Creates a named binding container, the top bindings model object.
  # A NamedBindings is typically produced by a bindings provider.
  #
  # The created container is wrapped in a BindingsContainerBuilder for further detailing.
  # Unwrap the built result when done.
  # @api public
  #
  def self.named_bindings(name, &block)
    binding = Bindings::NamedBindings.new()
    binding.name = name
    builder = BindingsContainerBuilder.new(binding)
    builder.instance_eval(&block) if block_given?
    builder
  end

  # This variant of {named_bindings} evaluates the given block as a method on an anonymous class,
  # thus, if the block defines methods or do something with the class itself, this does not pollute
  # the base class (BindingsContainerBuilder).
  # @api private
  #
  def self.safe_named_bindings(name, scope, &block)
    binding = Bindings::NamedBindings.new()
    binding.name = name
    anon = Class.new(BindingsContainerBuilder) do
      def initialize(b)
        super b
      end
    end
    anon.send(:define_method, :_produce, block)
    builder = anon.new(binding)
    case block.arity
    when 0
      builder._produce()
    when 1
      builder._produce(scope)
    end
    builder
  end

  # Creates a literal/constant producer
  # @param value [Object] the value to produce
  # @return [Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.literal_producer(value)
    producer = Bindings::ConstantProducerDescriptor.new()
    producer.value = value
    producer
  end

  # Creates a non caching producer
  # @param producer [Bindings::Producer] the producer to make non caching
  # @return [Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.non_caching_producer(producer)
    p = Bindings::NonCachingProducerDescriptor.new()
    p.producer = producer
    p
  end

  # Creates a producer producer
  # @param producer [Bindings::Producer] a producer producing a Producer.
  # @return [Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.producer_producer(producer)
    p = Bindings::ProducerProducerDescriptor.new()
    p.producer = producer
    p
  end

  # Creates an instance producer
  # An instance producer creates a new instance of a class.
  # If the class implements the class method `inject` this method is called instead of `new` to allow further lookups
  # to take place. This is referred to as *assisted inject*. If the class method `inject` is missing, the regular `new` method
  # is called.
  #
  # @param class_name [String] the name of the class
  # @param args[Object] arguments to the class' `new` method.
  # @return [Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.instance_producer(class_name, *args)
    p = Bindings::InstanceProducerDescriptor.new()
    p.class_name = class_name
    args.each {|a| p.addArguments(a) }
    p
  end

  # Creates a Producer that looks up a value.
  # @param type [Types::PAnyType] the type to lookup
  # @param name [String] the name to lookup
  # @return [Bindings::ProducerDescriptor] a producer description
  # @api public
  def self.lookup_producer(type, name)
    p = Bindings::LookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p
  end

  # Creates a Hash lookup producer that looks up a hash value, and then a key in the hash.
  #
  # @return [Bindings::ProducerDescriptor] a producer description
  # @param type [Types::PAnyType] the type to lookup (i.e. a Hash of some key/value type).
  # @param name [String] the name to lookup
  # @param key [Object] the key to lookup in the looked up hash (type should comply with given key type).
  # @api public
  #
  def self.hash_lookup_producer(type, name, key)
    p = Bindings::HashLookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p.key = key
    p
  end

  # Creates a first-found producer that looks up from a given series of keys. The first found looked up
  # value will be produced.
  # @param producers [Array<Bindings::ProducerDescriptor>] the producers to consult in given order
  # @return [Bindings::ProducerDescriptor] a producer descriptor
  # @api public
  def self.first_found_producer(*producers)
    p = Bindings::FirstFoundProducerDescriptor.new()
    producers.each {|p2| p.addProducers(p2) }
    p
  end

  # Creates an evaluating producer that evaluates a puppet expression.
  # A puppet expression is most conveniently created by using the {Parser::EvaluatingParser EvaluatingParser} as it performs
  # all set up and validation of the parsed source. Two convenience methods are used to parse an expression, or parse a ruby string
  # as a puppet string. See methods {puppet_expression}, {puppet_string} and {parser} for more information.
  #
  # @example producing a puppet expression
  #     expr = puppet_string("Interpolated $fqdn", __FILE__)
  #
  # @param expression [Model::Expression] a puppet DSL expression as producer by the eparser.
  # @return [Bindings::ProducerDescriptor] a producer descriptor
  # @api public
  #
  def self.evaluating_producer(expression)
    p = Bindings::EvaluatingProducerDescriptor.new()
    p.expression = expression
    p
  end

  # Creates a NamedLayer. This is used by the bindings system to create a model of the layers.
  #
  # @api public
  #
  def self.named_layer(name, *bindings)
    result = Bindings::NamedLayer.new()
    result.name = name
    bindings.each { |b| result.addBindings(b) }
    result
  end

  # Create a LayeredBindings. This is used by the bindings system to create a model of all given layers.
  # @param named_layers [Bindings::NamedLayer] one or more named layers
  # @return [Bindings::LayeredBindings] the constructed layered bindings.
  # @api public
  #
  def self.layered_bindings(*named_layers)
    result = Bindings::LayeredBindings.new()
    named_layers.each {|b| result.addLayers(b) }
    result
  end

  # @return [Parser::EvaluatingParser] a parser for puppet expressions
  def self.parser
    @parser ||= Parser::EvaluatingParser.new()
  end

  # Parses and produces a puppet expression from the given string.
  # @param string [String] puppet source e.g. "1 + 2"
  # @param source_file [String] the source location, typically `__File__`
  # @return [Model::Expression] an expression (that can be bound)
  # @api public
  #
  def self.puppet_expression(string, source_file)
    parser.parse_string(string, source_file).current
  end

  # Parses and produces a puppet string expression from the given string.
  # The string will automatically be quoted and special characters escaped.
  # As an example if given the (ruby) string "Hi\nMary" it is transformed to
  # the puppet string (illustrated with a ruby string) "\"Hi\\nMary\”" before being
  # parsed.
  #
  # @param string [String] puppet source e.g. "On node $!{fqdn}"
  # @param source_file [String] the source location, typically `__File__`
  # @return [Model::Expression] an expression (that can be bound)
  # @api public
  #
  def self.puppet_string(string, source_file)
    parser.parse_string(parser.quote(string), source_file).current
  end
end
end
end
