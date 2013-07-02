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
      binding = Puppet::Pops::Binder::Bindings::MultiBinding.new()
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
    def to(producer)
      # If given producer is not a producer, create a literal producer
      unless producer.is_a?(Puppet::Pops::Binder::Bindings::ProducerDescriptor)
        producer = Puppet::Pops::Binder::BindingsFactory.literal_producer(producer)
      end
      @model.producer = producer
      self
    end

    # to a "non singleton" producer (each produce produces a new copy).
    #
    def to_series_of(producer)
      # If given producer is not a producer, create a literal producer
      unless producer.is_a?(Puppet::Pops::Binder::Bindings::ProducerDescriptor)
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
  end

  class MultibindingsBuilder < BindingsBuilder
    def model_type=(type)
      unless type.is_a?(Puppet::Pops::Types::PArrayType) || type.is_a?(Puppet::Pops::Types::PArrayType)
        raise ArgumentError, 'Wrong type; only PArrayType, or PHashType allowed'
      end
      @model.type = type
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

  def self.lookup_producer(type, name)
    p = Puppet::Pops::Binder::Bindings::LookupProducerDescriptor.new()
    p.type = type
    p.name = name
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
end