# A helper class that makes it easier to construct a Bindings model
#
# @example Usage of the factory
#   result = Puppet::Pops::Binder::BindingsFactory.named_bindings("mymodule::mybindings")
#   result.bind().name("foo").to(42)
#   result.when_in_category("node", "kermit.example.com").bind().name("foo").to(43)
#   result.bind().string().name("site url").to("http://www.example.com")
#   result.model()
#
# @api public
#
module Puppet::Pops::Binder::BindingsFactory

  class AbstractBuilder
    # The built model object.
    attr_reader :model

    # @api public
    def initialize(binding)
      @model = binding
    end

    # Provides convenient access to the Bindings Factory class methods. The intent is to provide access to the
    # methods that return producers for the purpose of composing more elaborate things that the convenient methods
    # directly supports.
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

  # @api public
  class BindingsContainerBuilder < AbstractBuilder

    # Adds an empty binding to the container, and returns a builder for it for further detailing.
    # @api public
    #
    def bind(&block)
      binding = Puppet::Pops::Binder::Bindings::Binding.new()
      model.addBindings(binding)
      builder = BindingsBuilder.new(binding)
      builder.instance_eval(&block) if block_given?
      builder
    end

    # Binds an (almost) empty multibind where later, the looked up result contains all contributions to this key
    # @param id [String] the multibind's id used when adding contributions
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
    # bindings in that container.
    # @param categorixation [String] the name of the categorization e.g. 'node'
    # @param category_vale [String] the calue in that category e.g. 'kermit.example.com'
    # @api public
    #
    def when_in_category(categorization, category_value, &block)
      when_in_categories({categorization => category_value}, &block)
    end

    # Adds a categorized bindings to this container. Returns a BindingsContainerBuilder to allow adding
    # bindings in that container. The result is that a processed request must be in all the listed categorizations
    # with the given values.
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

    # Makes the binding a multibind contribution to the given multibind id
    # @api public
    def in_multibind(id)
      model.multibind_id = id
      self
    end

    # (#name)
    # @api public
    def named(name)
      model.name = name
      self
    end

    # @api public
    def type(type)
      model.type = type
      self
    end

    # @api public
    def integer()
      type(type_factory.integer())
    end

    # @api public
    def float()
      type(type_factory.float())
    end

    # @api public
    def boolean()
      type(type_factory.boolean())
    end

    # @api public
    def string()
      type(type_factory.string())
    end

    # @api public
    def pattern()
      type(type_factory.pattern())
    end

    # @api public
    def literal()
      type(type_factory.literal())
    end

    # @api public
    def data()
      type(type_factory.data())
    end

    # @api public
    def array_of_data()
      type(type_factory.array_of_data())
    end

    # @api public
    def array_of(t)
      type(type_factory.array_of(t))
    end

    # @api public
    def hash_of_data()
      type(type_factory.hash_of_data())
    end

    # Sets type of binding to `Hash[Literal, t]`. To limit the key type, use {#type} and give it a fully specified
    # hash using {#type_factory} and then `hash_of(value_type, key_type)`.
    # @api public
    def hash_of(t)
      type(type_factory.hash_of(t))
    end

    # @api public
    def instance_of(t)
      type(type_factory.type_of(t))
    end

    # Provides convenient access to the type factory.
    # This is intended to be used when methods taking a type as argument i.e. {#type}, #{array_of}, {#hash_of}, and {#instance_of}.
    #
    # @api public
    def type_factory
      Puppet::Pops::Types::TypeFactory
    end

    # to a singleton producer, if producer is a value, a literal producer is created for it
    # @overload to(a_literal)
    #   a constant producer
    # @overload to(a_class, *args)
    #   Instantiating producer
    # @overload to(a_producer_descriptor)
    #   a given producer
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

    # To a producer of an instance of given class (a String class name, or a Class instance)
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

    # to a singleton producer
    # @overload to_producer(a_producer)
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
        raise ArgumentError, "Given producer argument is neither a producer descriptor, a class, nor a producer"
      end
      metaproducer = Puppet::Pops::Binder::BindingsFactory.producer_producer(producer)
      model.producer = metaproducer
      self
    end

    # to a series of producers
    # @overload to_producer(a_producer)
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
        raise ArgumentError, "Given producer argument is neither a producer descriptor, a class, nor a producer"
      end
      non_caching = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = producer
      metaproducer = Puppet::Pops::Binder::BindingsFactory.producer_producer(non_caching)

      non_caching = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
      non_caching.producer = metaproducer

      model.producer = non_caching
      self
    end

    # to a "non singleton" producer (each produce produces a new copy).
    # @overload to_series_of(a_literal)
    #   a constant producer
    # @overload toto_series_of(a_class, *args)
    #   Instantiating producer
    # @overload toto_series_of(a_producer_descriptor)
    #   a given producer
    #
    # @api public
    #
    def to_series_of(producer)
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

    # to a lookup of another key
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

    # to a lookup of another key
    # @overload to_lookup_of(type, name)
    # @overload to_lookup_of(name)
    # @api public
    #
    def to_hash_lookup_of(type, name, key)
      model.producer = Puppet::Pops::Binder::BindingsFactory.hash_lookup_producer(type, name, key)
      self
    end

    # to first found lookup of another key
    # @param list_of_lookups [Array] array of arrays [type name], or just name (implies data)
    # @example
    #   binder.bind().name('foo').to_first_found(['fee', 'fum', 'extended-bar'])
    #   binder.bind().name('foo').to_first_found([
    #     [TypeFactory.ruby(ThisClass), 'fee'],
    #     [TypeFactory.ruby(ThatClass), 'fum'],
    #     'extended-bar'])
    # @api public
    #
    def to_first_found(list_of_lookups)
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
          Puppet::Pops::Binder::BindingsFactory.lookup_producer(Puppet::Pops::Types::TypeFactory.data(), entry)
        end
      end
      model.producer = Puppet::Pops::Binder::BindingsFactory.first_found_producer(producers)
      self
    end

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

  # Produces a ContributedBindings
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

  # This variant of named_binding evaluates the given block as a method on an anonymous class,
  # thus, if the block defines methods or do something with the class itself, this does not pollute
  # the base class (BindingsContainerBuilder).
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

  # Creates a literal producer
  # @api public
  #
  def self.literal_producer(value)
    producer = Puppet::Pops::Binder::Bindings::ConstantProducerDescriptor.new()
    producer.value = value
    producer
  end

  # Creates a literal producer
  # @api public
  #
  def self.non_caching_producer(producer)
    p = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
    p.producer = producer
    p
  end

  # Creates a producer producer
  # @api public
  #
  def self.producer_producer(producer)
    p = Puppet::Pops::Binder::Bindings::ProducerProducerDescriptor.new()
    p.producer = producer
    p
  end

  # @api public
  #
  def self.instance_producer(class_name, *args)
    p = Puppet::Pops::Binder::Bindings::InstanceProducerDescriptor.new()
    p.class_name = class_name
    args.each {|a| p.addArguments(a) }
    p
  end

  # @api public
  def self.lookup_producer(type, name)
    p = Puppet::Pops::Binder::Bindings::LookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p
  end

  # @api public
  def self.hash_lookup_producer(type, name, key)
    p = Puppet::Pops::Binder::Bindings::HashLookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p.key = key
    p
  end

  # @api public
  def self.first_found_producer(producers)
    p = Puppet::Pops::Binder::Bindings::FirstFoundProducerDescriptor.new()
    producers.each {|p2| p.addProducers(p2) }
    p
  end

  # @api public
  def self.evaluating_producer(expression)
    p = Puppet::Pops::Binder::Bindings::EvaluatingProducerDescriptor.new()
    p.expression = expression
    p
  end

  # Creates an EffectiveCategories from a list of tuples `[categorizxation category ...]`, or ´[[categorization category] ...]`
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

  # @api public
  def self.named_layer(name, *bindings)
    result = Puppet::Pops::Binder::Bindings::NamedLayer.new()
    result.name = name
    bindings.each { |b| result.addBindings(b) }
    result
  end

  # @api public
  def self.layered_bindings(*named_layers)
    result = Puppet::Pops::Binder::Bindings::LayeredBindings.new()
    named_layers.each {|b| result.addLayers(b) }
    result
  end

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
