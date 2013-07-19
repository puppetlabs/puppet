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
class Puppet::Pops::Binder::BindingsFactory

  # @api public
  class BindingsContainerBuilder
    # The built model object.
    attr_reader :model

    # @api public
    def initialize(binding)
      @model = binding
    end

    # Adds an empty binding to the container, and returns a builder for it for further detailing.
    # @api public
    #
    def bind()
      binding = Puppet::Pops::Binder::Bindings::Binding.new()
      model.addBindings(binding)
      BindingsBuilder.new(binding)
    end

    # Binds an (almost) empty multibind where later, the looked up result contains all contributions to this key
    # @param id [String] the multibind's id used when adding contributions
    # @api public
    #
    def multibind(id)
      binding = Puppet::Pops::Binder::Bindings::Multibinding.new()
      binding.id = id
      model.addBindings(binding)
      MultibindingsBuilder.new(binding)
    end

    # Binds a type/name key in a multibind given by id.
    # @param type [Puppet::Pops::Types::PObjectType] the type (must be compatible with the multibind type argument)
    # @param name [String] the name of the binding (appears as key in a Hash multibind, ignored in an Array multibind
    # @param id [String] the multibind id of the multibind where this binding should be made
    # @api public
    #
    def bind_in_multibind(id)
      binding = Puppet::Pops::Binder::Bindings::MultibindContribution.new()
      binding.multibind_id = id
      model.addBindings(binding)
      BindingsBuilder.new(binding)
    end

    # Adds a categorized bindings to this container. Returns a BindingsContainerBuilder to allow adding
    # bindings in that container.
    # @param categorixation [String] the name of the categorization e.g. 'node'
    # @param category_vale [String] the calue in that category e.g. 'kermit.example.com'
    # @api public
    #
    def when_in_category(categorization, category_value)
      when_in_categories({categorization => category_value})
    end

    # Adds a categorized bindings to this container. Returns a BindingsContainerBuilder to allow adding
    # bindings in that container. The result is that a processed request must be in all the listed categorizations
    # with the given values.
    # @param categories_hash Hash[String, String] a hash with categorization and categorization value entries
    # @api public
    #
    def when_in_categories(categories_hash)
      binding = Puppet::Pops::Binder::Bindings::CategorizedBindings.new()
      categories_hash.each do |k,v|
          pred = Puppet::Pops::Binder::Bindings::Category.new()
          pred.categorization = k
          pred.value = v
          binding.addPredicates(pred)
        end
      model.addBindings(binding)
      BindingsContainerBuilder.new(binding)
    end
  end

  # Builds a Binding via cconvenience methods.
  #
  # @api public
  #
  class BindingsBuilder
    attr_reader :model

    # @api public
    def initialize(binding)
      @model = binding
      data()
    end

    # @api public
    def name(name)
      @model.name = name
      self
    end

    # @api public
    def type(type)
      @model.type = type
      self
    end

    # @api public
    def integer()
      type(Puppet::Pops::Types::TypeFactory.integer())
    end

    # @api public
    def float()
      type(Puppet::Pops::Types::TypeFactory.float())
    end

    # @api public
    def boolean()
      type(Puppet::Pops::Types::TypeFactory.boolean())
    end

    # @api public
    def string()
      type(Puppet::Pops::Types::TypeFactory.string())
    end

    # @api public
    def pattern()
      type(Puppet::Pops::Types::TypeFactory.pattern())
    end

    # @api public
    def literal()
      type(Puppet::Pops::Types::TypeFactory.literal())
    end

    # @api public
    def data()
      type(Puppet::Pops::Types::TypeFactory.data())
    end

    # @api public
    def array_of_data()
      type(Puppet::Pops::Types::TypeFactory.array_of_data())
    end

    # @api public
    def array_of(t)
      type(Puppet::Pops::Types::TypeFactory.array_of(t))
    end

    # @api public
    def hash_of_data()
      type(Puppet::Pops::Types::TypeFactory.hash_of_data())
    end

    # @api public
    def hash_of(t)
      type(Puppet::Pops::Types::TypeFactory.hash_of(t))
    end

    # @api public
    def instance_of(t)
      type(Puppet::Pops::Types::TypeFactory.type_of(t))
    end

    # to a singleton producer, if producer is a value, a producer is created for it
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
      @model.producer = producer
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
      @model.producer = Puppet::Pops::Binder::BindingsFactory.instance_producer(class_name, *args)
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
      @model.producer = metaproducer
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

      @model.producer = non_caching
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
      @model.producer = non_caching
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
      @model.producer = Puppet::Pops::Binder::BindingsFactory.lookup_producer(type, name)
      self
    end

    # to a lookup of another key
    # @overload to_lookup_of(type, name)
    # @overload to_lookup_of(name)
    # @api public
    #
    def to_hash_lookup_of(type, name, key)
      @model.producer = Puppet::Pops::Binder::BindingsFactory.hash_lookup_producer(type, name, key)
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
      @model.producer = Puppet::Pops::Binder::BindingsFactory.first_found_producer(producers)
      self
    end

    # @api public
    def producer_options(options)
      options.each do |k, v|
        arg = Puppet::Pops::Binder::Bindings::NamedArgument.new()
        arg.name = k.to_s
        arg.value = v
        @model.addProducer_args(arg)
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
      @model.type = type
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
  def self.named_bindings(name)
    binding = Puppet::Pops::Binder::Bindings::NamedBindings.new()
    binding.name = name
    BindingsContainerBuilder.new(binding)
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
end
