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
    @@producer_visitor ||= Puppet::Pops::Visitor.new(nil,"produce", 2,  2)
  end

  # Lookup (a.k.a "inject") of a value given a key.
  # The lookup may be called with different parameters. This method is a convenience method that
  # dispatches to one of #lookup_key or #lookup_type depending on the arguments
  #
  # @overload lookup(scope, key)
  #   (see #lookup_key)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param key [Object] an opaque object being the full key
  #
  # @overload lookup(scope, type, name = '')
  #  (see #lookup_type)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param type [Puppet::Pops::Types::PObjectType], the type of what to lookup
  #   @param name [String], the name to use, defaults to empty string (for unnamed)
  #
  # @overload lookup(scope, name)
  #  Lookup of Data type with given name.
  #   @see #lookup_type
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param name [String], the Data/name to lookup
  #
  # @api public
  #
  def lookup(scope, *args)
    raise ArgumentError, "lookup should be called with two or three arguments, got: #{args.size()+1}" unless args.size <= 2
    case args[0]
    when Puppet::Pops::Types::PObjectType
      lookup_type(scope, *args)
    when String
      raise ArgumentError, "lookup of name should only pass the name" unless args.size == 1
      lookup_key(scope, key_factory.data_key(args[0]))
    else
      raise ArgumentError, "lookup using a key should only pass a single key" unless args.size == 1
      lookup_key(scope, args[0])
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
  def lookup_type(scope, type, name='')
    produce(scope, type, lookup_key(named_key(type, name)))
  end

  # Looks up the key and returns the entry, or nil if no entry is found.
  # Produced type is checked for type conformance with its binding, but not with the lookup key.
  # (This since all subtypes of PDataType are looked up using a key based on PDataType).
  # Use the Puppet::Pops::Types::TypeCalculator#assignable? method to check for conformance of the result
  # if this is wanted, or use #lookup_type.
  # @param key [Object] lookup of key as produced by the key factory
  # @api public
  #
  def lookup_key(scope, key)
    entry = entries[key]
    return nil unless entry # not found
  end

  def lookup_producer(scope, *args)
  end

  def lookup_producer_key(scope, key)
  end

  def lookup_producer_type(scope, type, name='')
  end

  # TODO: Optional Producers; they should have a list of other producers (to be tested in turn for production) ??
  #
  def produce(scope, type, entry)
    return nil unless entry # not found
    unless cached = entry.cached_producer
      entry.cached_producer = @@producer_visitor.visit_this(self, entry.producer, scope, entry)
    end
    cached.call(scope)
  end

  # Called when producer is missing (e.g. a Multibinding)
  #
  def produce_NilClass(producer, entry)
    unless entry.binding.is_a?(Puppet::Pops::Binder::Bindings::Multibinding)
      raise ArgumentError, "Binding without producer detected (TODO: details)"
    end
    
  end

  # Produces a constant value
  # If not a singleton the value is deep-cloned (if not immutable) before returned.
  #
  def produce_ConstantProducerDescriptor(descriptor, scope, entry)
    if caching?(descriptor)
      deep_cloning_producer(descriptor.value)
    else
      singleton_producer(descriptor.value)
    end
  end

  # Produces a new instance of the given class with given initialization arguments
  # If a singleton, the producer is asked to produce a single value and this is then considered a singleton.
  #
  def produce_InstanceProducer(descriptor, scope, entry)
    if caching?(descriptor)
      instantiating_producer.new(descriptor.class_name, *(descriptor.arguments))
    else
      singleton_producer(instantiating_producer(descriptor.class_name, *(descriptor.arguments)).call(scope))
    end
  end

  # Evaluates a contained expression. If this is a singleton, the evaluation is performed once.
  #
  def produce_EvaluatingProducerDescriptor(descriptor, scope, entry)
    if caching?(descriptor)
      evaluating_proucer(descriptor.expr)
    else
      singleton_producer(evaluating_proucer(descriptor.expr).call(scope))
    end
  end

  def caching?(descriptor)
    descriptor.eContainer().is_a?(Puppet::Pops::Binder::Bindings::NonCachingProducerDescriptor)
  end

  # This implementation simply delegates since caching status is determined by the polymorph produce_xxx method
  # per type (different actions taken depending on the type).
  #
  def produce_NonCachingProducerDescriptor(descriptor, scope, entry)
    # simply delegates to the wrapped producer
    produce(descritor.producer, scope, entry)
  end

  # TODO: MultiLookupProducerDescriptor

  # TODO: Add model, and implementation for a user supplied Producer
  # This could be a reference to a PType, which is instantiated, then it's #producer method is called to
  # return a Proc |scope|
  #


#  def produce_DynamicProducer(producer, entry)
#    unless cached = entry.cached_producer
#      args_hash = entry.arguments.reduce({}) {|memo, arg| memo[arg.name] = arg.value; memo }
#      cached = entry.cached_producer = Object.const_get(producer.class_name).new(args_hash)
#    end
#    return cached.produce()
#  end

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
  # These could be written as Procs

    def singleton_producer(value)
      Proc.new do |scope|
        return value
      end
    end

    def deep_cloning_producer(value)
      Proc.new do |scope|
        case value
        # These are immutable
        when Integer, Float, TrueClass, FalseClass, Symbol
          return value
        # ok if frozen
        when String
          return value if value.frozen?
        end

        # The default serialize/deserialize to get a deep copy
        Marshal.load(Marshal.dump(value))
      end
    end

    def instantiating_producer(class_name, *init_args)
      Proc.new do |scope|
        Object.const_get(class_name).new(*init_args)
      end
    end

    def evluating_producer(expr)
      puppet3_ast = Puppet::Pops::Model::AstTransformer.new().transform(expr)
      Proc.new do |scope|
        puppet_3_ast.evaluate(scope)
      end
    end

    def lookup_producer(type, name)
      Proc.new do |scope|
        lookup_type(scope, type, name)
      end
    end

end