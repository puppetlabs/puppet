# A helper class that makes it easier to construct a Bindings model.
#
# @example Create a NamedBinding with content
#   result = Puppet::Pops::Binder::BindingsFactory.named_bindings("mymodule::mybindings") do
#     bind.name("foo").to(42)
#     when_in_category("node", "kermit.example.com").bind.name("foo").to(43)
#     bind.string().name("site url").to("http://www.example.com")
#   end
#   result.model()
#
# @api public
#
module Puppet::Pops::Binder::BindingsFactory

  # Alias for the {Puppet::Pops::Types::TypeFactory TypeFactory}. This is also available as the method
  # `type_factory`.
  #
  T = Puppet::Pops::Types::TypeFactory

  # Abstract base class for bindings object builders.
  # Supports delegation of method calls to the BindingsFactory class methods for all methods not implemented
  # by a concrete builder.
  #
  # @abstract
  #
  class AbstractBuilder
    # The built model object.
    attr_reader :model

    # @param binding [Puppet::Pops::Binder::Bindings::AbstractBinding] The binding to build.
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
      factory = Puppet::Pops::Binder::BindingsFactory
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
      binding = Puppet::Pops::Binder::Bindings::Binding.new()
      model.addBindings(binding)
      builder = BindingsBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end

    # Binds an multibind with the given identity where later, the looked up result contains all
    # contributions to this key. An optional block may be given which is evaluated using `instance_eval`.
    # @param id [String] the multibind's id used when adding contributions
    # @return [MutibindingBuilder] the builder for the created multibinding
    # @api public
    #
    def multibind(id, &block)
      binding = Puppet::Pops::Binder::Bindings::Multibinding.new()
      binding.id = id
      model.addBindings(binding)
      builder = MultibindingsBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end

    # Adds a categorized bindings to this container. Returns a BindingsContainerBuilder to allow adding
    # bindings in the newly created container. An optional block may be given which is evaluated using `instance_eval`.
    # @param categorixation [String] the name of the categorization e.g. 'node'
    # @param category_vale [String] the calue in that category e.g. 'kermit.example.com'
    # @return [BindingsContainerBuilder] the builder for the created categorized bindings container
    # @api public
    #
    def when_in_category(categorization, category_value, &block)
      when_in_categories({categorization => category_value}, &block)
    end

    # Adds a categorized bindings to this container. Returns a BindingsContainerBuilder to allow adding
    # bindings in the newly created container.
    # The result is that a processed request must match all the given categorizations
    # with the given values. An optional block may be given which is evaluated using `instance_eval`.
    # @param categories_hash Hash[String, String] a hash with categorization and categorization value entries
    # @api public
    #
    def when_in_categories(categories_hash, &block)
      binding = Puppet::Pops::Binder::Bindings::CategorizedBindings.new()
      categories_hash.each do |k,v|
          pred = Puppet::Pops::Binder::Bindings::Category.new()
          pred.categorization = k
          pred.value = v
          binding.addPredicates(pred)
        end
      model.addBindings(binding)
      builder = BindingsContainerBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end
  end

  # Builds a Binding via convenience methods.
  #
  # @api public
  #
  class BindingsBuilder < AbstractBuilder

    # @param binding [Puppet::Pops::Binder::Bindings::AbstractBinding] the binding to build.
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
    #   {#integer}, {#literal}, {#pattern}, {#string}, or one of the collection methods #{array_of}, or #{hash_of}.
    #
    # To create a type, use the method {#type_factory}, to obtain the type.
    # @example creating a Hash with Integer key and Array[Integer] element type
    #     tc = type_factory
    #     type(tc.hash(tc.array_of(tc.integer), tc.integer)
    # @param type [Puppet::Pops::Types::PObjectType] the type to set for the binding
    # @api public
    #
    def type(type)
      model.type = type
      self
    end

    # Sets the type of the binding to Integer.
    # @return [Puppet::Pops::Types::PIntegerType] the type
    # @api public
    def integer()
      type(T.integer())
    end

    # Sets the type of the binding to Float.
    # @return [Puppet::Pops::Types::PFloatType] the type
    # @api public
    def float()
      type(T.float())
    end

    # Sets the type of the binding to Boolean.
    # @return [Puppet::Pops::Types::PBooleanType] the type
    # @api public
    def boolean()
      type(T.boolean())
    end

    # Sets the type of the binding to String.
    # @return [Puppet::Pops::Types::PStringType] the type
    # @api public
    def string()
      type(T.string())
    end

    # Sets the type of the binding to Pattern.
    # @return [Puppet::Pops::Types::PPatternType] the type
    # @api public
    def pattern()
      type(T.pattern())
    end

    # Sets the type of the binding to the abstract type Literal.
    # @return [Puppet::Pops::Types::PLiteralType] the type
    # @api public
    def literal()
      type(T.literal())
    end

    # Sets the type of the binding to the abstract type Data.
    # @return [Puppet::Pops::Types::PDataType] the type
    # @api public
    def data()
      type(T.data())
    end

    # Sets the type of the binding to Array[Data].
    # @return [Puppet::Pops::Types::PArrayType] the type
    # @api public
    def array_of_data()
      type(T.array_of_data())
    end

    # Sets the type of the binding to Array[T], where T is given.
    # @param t [Puppet::Pops::Types::PObjectType] the type of the elements of the array
    # @return [Puppet::Pops::Types::PArrayType] the type
    # @api public
    def array_of(t)
      type(T.array_of(t))
    end

    # Sets the type of the binding to Hash[Literal, Data].
    # @return [Puppet::Pops::Types::PHashType] the type
    # @api public
    def hash_of_data()
      type(T.hash_of_data())
    end

    # Sets type of the binding to `Hash[Literal, t]`.
    # To also limit the key type, use {#type} and give it a fully specified
    # hash using {#type_factory} and then `hash_of(value_type, key_type)`.
    # @return [Puppet::Pops::Types::PHashType] the type
    # @api public
    def hash_of(t)
      type(T.hash_of(t))
    end

    # Sets the type of the binding based on the given t.
    # @overload instance_of(t)
    #   The same as calling {#type} with `t`.
    #   @param t [Puppet::Pops::Types::PObjectType] the type
    # @overload instance_of(o)
    #   Infers the type from the given Ruby object and sets that as the type - i.e. "set the type
    #   of the binding to be that of the given data object".
    #   @param o [Object] the object to infert the type from
    # @overload instance_of(c)
    #   Sets the type based on the given ruby class. The result is one of the specific puppet types
    #   if the class can be represented by a specific type, or the open ended PRubyType otherwise.
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
    # This is intended to be used when methods taking a type as argument i.e. {#type}, #{array_of}, {#hash_of}, and {#instance_of}.
    # @note
    #   The type factory is also available via the constant {T}.
    # @api public
    def type_factory
      Puppet::Pops::Types::TypeFactory
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
        producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(producer.name, *args)
      when Puppet::Pops::Model::Expression
        producer = Puppet::Pops::Binder::BindingsFactory.evaluating_producer(producer)
      when Puppet::Pops::Binder::Bindings::ProducerDescriptor
      else
      # If given producer is not a producer, create a literal producer
        producer = Puppet::Pops::Binder::BindingsFactory.literal_producer(producer)
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
      model.producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(class_name, *args)
    end

    # Sets the binding's producer to a singleton producer
    # @overload to_producer(a_producer)
    #   Sets the producer to an instantiated producer. The resulting model can not be serialized as a consequence as there
    #   is no meta-model describing the specialized producer. Use this only in exceptional cases, or where there is never the
    #   need to serialize the model.
    #   @param a_producer [Puppet::Pops::Binder::Producers::Producer] an instantiated producer, not serializeable !
    #
    # @overload to_producer(a_class, *args)
    #   @param a_class [Class] the class to create an instance of
    #   @param args [Object] the arguments to the given class' new
    #
    # @overload to_producer(a_producer_descriptor)
    #   @param a_producer_descriptor [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a descriptor
    #      producing Puppet::Pops::Binder::Producers::Producer
    #
    # @api public
    #
    def to_producer(producer, *args)
      case producer
      when Class
        producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(producer.name, *args)
      when Puppet::Pops::Binder::Bindings::ProducerDescriptor
      when Puppet::Pops::Binder::Producers::Producer
        # a custom producer instance
        producer = Puppet::Pops::Binder::BindingsFactory.literal_producer(producer)
      else
        raise ArgumentError, "Given producer argument is none of a producer descriptor, a class, or a producer"
      end
      metaproducer = Puppet::Pops::Binder::BindingsFactory.producer_producer(producer)
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
    #   @param a_producer [Puppet::Pops::Binder::Producers::Producer] an instantiated producer, not serializeable !
    #
    # @overload to_producer(a_class, *args)
    #   @param a_class [Class] the class to create an instance of
    #   @param args [Object] the arguments to the given class' new
    #
    # @overload to_producer(a_producer_descriptor)
    #   @param a_producer_descriptor [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a descriptor
    #      producing Puppet::Pops::Binder::Producers::Producer
    #
    # @api public
    #
    def to_producer_series(producer, *args)
      case producer
      when Class
        producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(producer.name, *args)
      when Puppet::Pops::Binder::Bindings::ProducerDescriptor
      when Puppet::Pops::Binder::Producers::Producer
        # a custom producer instance
        producer = Puppet::Pops::Binder::BindingsFactory.literal_producer(producer)
      else
        raise ArgumentError, "Given producer argument is none of a producer descriptor, a class, or a producer"
      end
      non_caching = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = producer
      metaproducer = Puppet::Pops::Binder::BindingsFactory.producer_producer(non_caching)

      non_caching = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
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
        producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(producer.name, *args)
      when Puppet::Pops::Binder::Bindings::ProducerDescriptor
      else
      # If given producer is not a producer, create a literal producer
        producer = Puppet::Pops::Binder::BindingsFactory.literal_producer(producer)
      end
      non_caching = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
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
        type = Puppet::Pops::Types::TypeFactory.data()
      end
      model.producer = Puppet::Pops::Binder::BindingsFactory.lookup_producer(type, name)
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
      model.producer = Puppet::Pops::Binder::BindingsFactory.hash_lookup_producer(type, name, key)
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
            Puppet::Pops::Binder::BindingsFactory.lookup_producer(entry[0], entry[1])
          when 1
            Puppet::Pops::Binder::BindingsFactory.lookup_producer(Puppet::Pops::Types::TypeFactory.data(), entry[0])
          else
            raise ArgumentError, "Not an array of [type, name], name, or [name]"
          end
        else
          Puppet::Pops::Binder::BindingsFactory.lookup_producer(T.data(), entry)
        end
      end
      model.producer = Puppet::Pops::Binder::BindingsFactory.first_found_producer(*producers)
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
        arg = Puppet::Pops::Binder::Bindings::NamedArgument.new()
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
    # Constraints type to be one of {Puppet::Pops::Types::PArrayType PArrayType}, or {Puppet::Pops::Types:PHashType PHashType}.
    # @raise [ArgumentError] if type constraint is not met.
    # @api public
    def type(type)
      unless type.class == Puppet::Pops::Types::PArrayType || type.class == Puppet::Pops::Types::PHashType
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
  # @param named_bindings [Puppet::Pops::Binder::Bindings::NamedBindings, Array<Puppet::Pops::Binder::Bindings::NamedBindings>] the
  #   named bindings to include
  # @parm effective_categories [Puppet::Pops::Binder::Bindings::EffectiveCategories] the contributors opinion about categorization
  #   this is used to ensure consistent use of categories.
  #
  def self.contributed_bindings(name, named_bindings, effective_categories)
    cb = Puppet::Pops::Binder::Bindings::ContributedBindings.new()
    cb.name = name
    named_bindings = [named_bindings] unless named_bindings.is_a?(Array)
    named_bindings.each {|b| cb.addBindings(b) }
    cb.effective_categories = effective_categories
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
    binding = Puppet::Pops::Binder::Bindings::NamedBindings.new()
    binding.name = name
    builder = BindingsContainerBuilder.new(binding)
    builder.instance_eval(&block) if block_given?
    builder
  end

  # This variant of {#named_bindings} evaluates the given block as a method on an anonymous class,
  # thus, if the block defines methods or do something with the class itself, this does not pollute
  # the base class (BindingsContainerBuilder).
  # @api private
  #
  def self.safe_named_bindings(name, scope, &block)
    binding = Puppet::Pops::Binder::Bindings::NamedBindings.new()
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
  # @param [Object] the value to produce
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.literal_producer(value)
    producer = Puppet::Pops::Binder::Bindings::ConstantProducerDescriptor.new()
    producer.value = value
    producer
  end

  # Creates a non caching producer
  # @param producer [Puppet::Pops::Binder::Bindings::Producer] the producer to make non caching
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.non_caching_producer(producer)
    p = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
    p.producer = producer
    p
  end

  # Creates a producer producer
  # @param producer [Puppet::Pops::Binder::Bindings::Producer] a producer producing a Producer.
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.producer_producer(producer)
    p = Puppet::Pops::Binder::Bindings::ProducerProducerDescriptor.new()
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
  # @param *args[Object] arguments to the class' `new` method.
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @api public
  #
  def self.instance_producer(class_name, *args)
    p = Puppet::Pops::Binder::Bindings::InstanceProducerDescriptor.new()
    p.class_name = class_name
    args.each {|a| p.addArguments(a) }
    p
  end

  # Creates a Producer that looks up a value.
  # @param type [Puppet::Pops::Types::PObjectType] the type to lookup
  # @param name [String] the name to lookup
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @api public
  def self.lookup_producer(type, name)
    p = Puppet::Pops::Binder::Bindings::LookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p
  end

  # Creates a Hash lookup producer that looks up a hash value, and then a key in the hash.
  #
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer description
  # @param type [Puppet::Pops::Types::PObjectType] the type to lookup (i.e. a Hash of some key/value type).
  # @param name [String] the name to lookup
  # @param key [Object] the key to lookup in the looked up hash (type should comply with given key type).
  # @api public
  #
  def self.hash_lookup_producer(type, name, key)
    p = Puppet::Pops::Binder::Bindings::HashLookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p.key = key
    p
  end

  # Creates a first-found producer that looks up from a given series of keys. The first found looked up
  # value will be produced.
  # @param producers [Array<Puppet::Pops::Binder::Bindings::ProducerDescriptor>] the producers to consult in given order
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer descriptor
  # @api public
  def self.first_found_producer(*producers)
    p = Puppet::Pops::Binder::Bindings::FirstFoundProducerDescriptor.new()
    producers.each {|p2| p.addProducers(p2) }
    p
  end

  # Creates an evaluating producer that evaluates a puppet expression.
  # A puppet expression is most conveniently created by using the {Puppet::Pops::Parser::EvaluatingParser EvaluatingParser} as it performs
  # all set up and validation of the parsed source. Two convenience methods are used to parse an expression, or parse a ruby string
  # as a puppet string. See methods {#puppet_expression}, {#puppet_string} and {#parser} for more information.
  #
  # @example producing a puppet expression
  #     expr = puppet_string("Interpolated $fqdn", __FILE__)
  #
  # @param expression [Puppet::Pops::Model::Expression] a puppet DSL expression as producer by the eparser.
  # @return [Puppet::Pops::Binder::Bindings::ProducerDescriptor] a producer descriptor
  # @api public
  #
  def self.evaluating_producer(expression)
    p = Puppet::Pops::Binder::Bindings::EvaluatingProducerDescriptor.new()
    p.expression = expression
    p
  end

  # Creates an EffectiveCategories from a list of tuples `[categorizxation category ...]`, or ´[[categorization category] ...]`
  # This method is used by backends to create a model of the effective categories.
  # @api public
  #
  def self.categories(tuple_array)
    result = Puppet::Pops::Binder::Bindings::EffectiveCategories.new()
    tuple_array.flatten.each_slice(2) do |c|
      cat = Puppet::Pops::Binder::Bindings::Category.new()
      cat.categorization = c[0]
      cat.value = c[1]
      result.addCategories(cat)
    end
    result
  end

  # Creates a NamedLayer. This is used by the bindings system to create a model of the layers.
  #
  # @api public
  #
  def self.named_layer(name, *bindings)
    result = Puppet::Pops::Binder::Bindings::NamedLayer.new()
    result.name = name
    bindings.each { |b| result.addBindings(b) }
    result
  end

  # Create a LayeredBindings. This is used by the bindings system to create a model of all LayeredBindings.
  #
  # @api public
  #
  def self.layered_bindings(*named_layers)
    result = Puppet::Pops::Binder::Bindings::LayeredBindings.new()
    named_layers.each {|b| result.addLayers(b) }
    result
  end

  # @return [Puppet::Pops::Parser::EvaluatingParser] a parser for puppet expressions
  def self.parser
    @parser ||= Puppet::Pops::Parser::EvaluatingParser.new()
  end

  # Parses and produces a puppet expression from the given string.
  # @param string [String] puppet source e.g. "1 + 2"
  # @param source_file [String] the source location, typically `__File__`
  # @return [Puppet::Pops::Model::Expression] an expression (that can be bound)
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
  # @param string [String] puppet source e.g. "On node ${fqdn}"
  # @param source_file [String] the source location, typically `__File__`
  # @return [Puppet::Pops::Model::Expression] an expression (that can be bound)
  # @api public
  #
  def self.puppet_string(string, source_file)
    parser.parse_string(parser.quote(string), source_file).current
  end
end
