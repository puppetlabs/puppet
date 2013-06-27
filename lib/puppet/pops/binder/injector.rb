# The injector is the "lookup service" class
#
# Initialization
# --------------
# The injector is initialized with a configured Binder. The Binder instance contains a resolved set of key to "binding information"
# that is used to setup the injector.
#
# Lookup
# ------
# The #lookup method can be called with three different signatures; #lookup(key), #lookup_type(type, name), and #lookup(name).
#
#
class Puppet::Pops::Binder::Injector

  # Hash of key => InjectorEntry
  # @api private
  attr_reader :entries

  # The KeyFactory shared with the Binder
  # @api private
  attr_reader :key_factory

  # An Injector is initialized with a configured Binder.
  #
  # @param configured_binder [Puppet::Pops::Binder::Binder] the configured binder containing effective bindings
  # @raises ArgumentError if the given binder is not fully configured
  # @api public
  #
  def initialize(configured_binder)
    raise ArgumentError, "Given Binder is not configured" unless comfigured_binder.configured?()
    @entries             = configured_binder.injector_entries()

    # It is essential that the injector uses the same key factory as the binder since keys must be
    # represented the same (but still opaque) way.
    #
    @key_factory         = configured_binder.key_factory()
    @@producer_visitor ||= Puppet::Pops::Visitor.new(nil,"produce",1,1)
  end

  # Lookup (a.k.a "inject") of a value given a key.
  # The lookup may be called with different parameters. This method is a convenience method that
  # dispatches to one of #lookup_key or #lookup_type depending on the arguments
  #
  # @overload lookup(key)
  #   (see #lookup_key)
  #   @param key [Object] an opaque object being the full key
  #
  # @overload lookup(type, name = '')
  #  (see #lookup_type)
  #   @param type [Puppet::Pops::Types::PObjectType], the type of what to lookup
  #   @param name [String], the name to use, defaults to empty string (for unnamed)
  #
  # @overload lookup(name)
  #  Lookup of Data type with given name.
  #   @see #lookup_type
  #   @param name [String], the Data/name to lookup
  #
  # @api public
  #
  def lookup(*args)
    raise ArgumentError, "lookup should be called with 1 or two arguments, got: #{args.size()}" unless args.size <= 2
    case args[0]
    when Puppet::Pops::Types::PObjectType
      lookup_type(*args)
    when String
      raise ArgumentError, "lookup of name with two arguments" unless args.size == 1
      lookup_key(key_factory.data_key(args[0]))
    else
      raise ArgumentError, "lookup using a key passing two arguments" unless args.size == 1
      lookup_key(args[0])
    end
  end

  # Produces a key for a type/name combination.
  # Specialization of the PDataType are transformed to a PDataType key
  #
  # @param type [Puppet::Pops::Types::PObjectType], the type the key should be based on
  # @param name [String]='', the name to base the key on for named keys.
  # @api public
  #
  def named_key(type, name)
    key_factory.named_key(type, name='')
  end

  # Produces a key for a PDataType/name combination
  # @param name [String], the name to base the key on.
  # @api public
  #
  def data_key(name)
    key_factory.data_key(name)
  end

  # Creates a key for the type/name combination using a KeyFactory. Specialization of the Data type are transformed
  # to a Data key, and the result is type checked to conform with the given key.
  #
  # @param type [Puppet::Pops::Types::PObjectType] the type to lookup as defined by Puppet::Pops::Types::TypeFactory
  # @param name [String] the optional name of the entry to lookup
  # @return [Object, nil] the looked up bound object, or nil if not found
  # @api public
  #
  def lookup_type(type, name='')
    produce(type, lookup_key(named_key(type, name)))
  end

  # Looks up the key and returns the entry, or nil if no entry is found.
  # Produced type is checked for type conformance with its binding, but not with the lookup key.
  # (This since all subtypes of PDataType are looked up using a key based on PDataType).
  # Use the Puppet::Pops::Types::TypeCalculator#assignable? method to check for conformance of the result
  # if this is wanted, or use #lookup_type.
  # @param key [Object] lookup of key as produced by the key factory
  # @api public
  #
  def lookup_key(key)
    entry = entries[key]
    return nil unless entry # not found
  end

  def lookup_producer(*args)
  end

  def lookup_producer_key(key)
  end

  def lookup_producer_type(type, name='')
  end

  # TODO: Optional Producers; they should have a list of other producers (to be tested in turn for production)
  # TODO: if producers are singleton producers (like the literal) or not, use composition with dynamic? or singleton?
  #
  def produce(type, entry)
    return nil unless entry # not found
    if cached = entry.cached
      return cached
    end
    @@producer_visitor.visit_this(self, entry.producer, entry)
  end

  # Called when producer is missing (e.g. a Multibinding)
  #
  def produce_NilClass(producer, entry)
    unless entry.binding.is_a?(Puppet::Pops::Binder::Bindings::Multibinding)
      raise ArgumentError, "Binding without producer detected (TODO: details)"
    end
    
  end

  # singleton
  def produce_LiteralProducer(producer, entry)
    entry.cached_producer = SingletonProducer.new(producer.value)
  end

  # singleton
  def produce_InstanceProducer(producer, entry)
    entry.cached_producer = SingletonProducer.new(Object.const_get(producer.class_name).new(*(producer.arguments)))
  end

  def produce_DynamicProducer(producer, entry)
    unless cached = entry.cached_producer
      args_hash = entry.arguments.reduce({}) {|memo, arg| memo[arg.name] = arg.value; memo }
      cached = entry.cached_producer = Object.const_get(producer.class_name).new(args_hash)
    end
    return cached.produce()
  end

  # TODO:
  # - producers in the bindings model are instructions, the real producers are defined here (they respond to
  # to #produce() )
  # - the model's Producer should define if a producer is singleton or not
  #   either via an attribute, or a wrapper that makes it a non singleton producer (otherwise all producers
  #   are singletons
  # - a constant/literal producer is different in that it can never producer a new object (except by cloning which
  #   is never a deep clone in Ruby
  #   (modeled objects are however deeply cloned, and when PuppetTyped objects are used based on a model this will
  #   work well just not for ruby objects)
  #   Suggest having a Fake impl using Ruby shallow clone, or using the ugly Marshal.load(Marshal.dump))
  # - Check what RGen does
  #
  # @api private
  class SingletonProducer
    attr_reader :produce
    def initialize(value)
      @produce = value
    end
  end

  class RepeatingProducer
    attr_reader :producer
    def initialize(producer)
      @producer = producer
    end
    def produce()
      producer().produce()
    end
  end
end