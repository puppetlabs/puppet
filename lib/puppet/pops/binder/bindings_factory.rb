# A helper class that makes it easier to construct a Bindings model
#
# Sample:
#   factory = Puppet::Pops__Binder::BindingsFactory.new()
#   result = factory.named_bindings("mymodule::mybindings")
#   result.bind().name("foo").to(42)
#   result.when_in_category("node", "kermit.example.com").bind().name("foo").to(43)
#   result.bind().string().name("site url").to("http://www.example.com")
#   result.model()
#
class Puppet::Pops::Binder::BindingsFactory

  class BindingsContainerBuilder
    # The built model object.
    attr_reader :model

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

  class BindingsBuilder
    attr_reader :model

    def initialize(binding)
      @model = binding
      data()
    end

    def model_type=(t)
      @model.type = t
    end

    def name(name)
      @model.name = name
      self
    end

    def type(type)
      @model.type = type
      self
    end

    def integer()
      @model.type = Puppet::Pops::Types::TypeFactory.integer()
      self
    end

    def float()
      @model.type = Puppet::Pops::Types::TypeFactory.float()
      self
    end

    def boolean()
      @model.type = Puppet::Pops::Types::TypeFactory.boolean()
      self
    end

    def string()
      @model.type = Puppet::Pops::Types::TypeFactory.string()
      self
    end

    def pattern()
      @model.type = Puppet::Pops::Types::TypeFactory.pattern()
      self
    end

    def literal()
      @model.type = Puppet::Pops::Types::TypeFactory.literal()
      self
    end

    def data()
      @model.type = Puppet::Pops::Types::TypeFactory.data()
      self
    end

    def array_of_data()
      @model.type = Puppet::Pops::Types::TypeFactory.array_of_data()
      self
    end

    def array_of(t)
      @model.type = Puppet::Pops::Types::TypeFactory.array_of(t)
      self
    end

    def hash_of_data()
      @model.type = Puppet::Pops::Types::TypeFactory.hash_of_data()
      self
    end

    def hash_of(t)
      @model.type = Puppet::Pops::Types::TypeFactory.hash_of(t)
      self
    end

    # to a singleton producer, if producer is a value, a producer is created for it
    # @overload to(a_literal)
    #   a constant producer
    # @overload to(a_class, *args)
    #   Instantiating producer
    # @overload to(a_producer_descriptor)
    #   a given producer
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


  class MultibindingsBuilder < BindingsBuilder
    def model_type=(type)
      unless type.is_a?(Puppet::Pops::Types::PArrayType) || type.is_a?(Puppet::Pops::Types::PArrayType)
        raise ArgumentError, 'Wrong type; only PArrayType, or PHashType allowed'
      end
      @model.type = type
    end

    def combinator(x)
      @model.combinator = Puppet::Pops::Binder::BindingsFactory::combinator(x)
      self
    end
  end

  # Creates a named binding container, the top bindings model object.
  # The created container is wrapped in a BindingsContainerBuilder for further detailing.
  # Unwrap the built result when done.
  #
  def self.named_bindings(name)
    binding = Puppet::Pops::Binder::Bindings::NamedBindings.new()
    binding.name = name
    BindingsContainerBuilder.new(binding)
  end

  # Creates a literal producer
  def self.literal_producer(value)
    producer = Puppet::Pops::Binder::Bindings::ConstantProducerDescriptor.new()
    producer.value = value
    producer
  end

  # Creates a literal producer
  def self.non_caching_producer(producer)
    p = Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor.new()
    p.producer = producer
    p
  end

  # Creates a producer producer
  def self.producer_producer(producer)
    p = Puppet::Pops::Binder::Bindings::ProducerProducerDescriptor.new()
    p.producer = producer
    p
  end

  def self.instance_producer(class_name, *args)
    p = Puppet::Pops::Binder::Bindings::InstanceProducerDescriptor.new()
    p.class_name = class_name
    args.each {|a| p.addArguments(a) }
    p
  end

  def self.lookup_producer(type, name)
    p = Puppet::Pops::Binder::Bindings::LookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p
  end

  def self.hash_lookup_producer(type, name, key)
    p = Puppet::Pops::Binder::Bindings::HashLookupProducerDescriptor.new()
    p.type = type
    p.name = name
    p.key = key
    p
  end

  def self.first_found_producer(producers)
    p = Puppet::Pops::Binder::Bindings::FirstFoundProducerDescriptor.new()
    producers.each {|p2| p.addProducers(p2) }
    p
  end

  def self.evaluating_producer(expression)
    p = Puppet::Pops::Binder::Bindings::EvaluatingProducerDescriptor.new()
    p.expression = expression
    p
  end

  # Creates an EffectiveCategories from a list of tuples `[categorizxation category ...]`, or ´[[categorization category] ...]`
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

  def self.named_layer(name, *bindings)
    result = Puppet::Pops::Binder::Bindings::NamedLayer.new()
    result.name = name
    bindings.each { |b| result.addBindings(b) }
    result
  end

  def self.layered_bindings(*named_layers)
    result = Puppet::Pops::Binder::Bindings::LayeredBindings.new()
    named_layers.each {|b| result.addLayers(b) }
    result
  end

  # Builds a Combinator from the given arguments.
  # A lambda based combinator takes different number of argumetns for Array/Hash multibinds. An array combinator
  # gets `memo` (the arrays current value), and `value`, and a hash combinator gets `memo` (the hash's current content),
  # `key` the current key, `current` (the current value at key), `value` the value to combine.
  #
  # @example an array combinator in Puppet DSL (concatenates)
  #   |$memo, $value| { $memo + [value] }
  #
  # @example a hash combinator in Puppet DSL (keeps first value set, ignores duplicates)
  #   |$memo, $key, $current, $value| { if $current { $current} else {$value} }
  #
  # @param x [Puppet::Pops::Model::LambdaExpression, Puppet::Pops::Binder::MultibindCombinators::Combinator] the combinator
  # @param *args [Object] arguments to an InstanceProducer (arguments passed to new for a given Combinator class)
  # @return [Puppet::Pops::Binder::Bindings::Combinator
  #
  def self.combinator(x, *args)

    if x.is_a?(Puppet::Pops::Model::LambdaExpression)
      c = Puppet::Pops::Binder::Bindings::CombinatorLambda.new()
      c.lambda = x
      c
    elsif x < Puppet::Pops::Binder::MultibindCombinators::Combinator
      c = Puppet::Pops::Binder::Bindings::CombinatorProducer.new()
      c.producer = instance_producer(x.name, *args)
      c
    else
      raise ArgumentError, "Cannot create a combinator from a: #{x.class}."
    end
  end
end