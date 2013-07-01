# The injector is the "lookup service" class
#
# Initialization
# --------------
# The injector is initialized with a configured Binder. The Binder instance contains a resolved set of key => "binding information"
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
    raise ArgumentError, "Given Binder is not configured" unless configured_binder && configured_binder.configured?()
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
  # TODO: Detailed error message
  #
  # @param type [Puppet::Pops::Types::PObjectType] the type to lookup as defined by Puppet::Pops::Types::TypeFactory
  # @param name [String] the optional name of the entry to lookup
  # @return [Object, nil] the looked up bound object, or nil if not found
  # @api public
  #
  def lookup_type(scope, type, name='')
    val = lookup_key(named_key(type, name))
    unless binder.type_calculator.assignable?(type, val)
      raise "Type error: incompatible type TODO: detailed error message"
    end
    val
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
    produce(scope, entries[key])
  end

  # Lookup (a.k.a "inject") producer of a value given a key.
  # The producer lookup may be called with different parameters. This method is a convenience method that
  # dispatches to one of #lookup_producer_key or #lookup_producer_type depending on the arguments
  #
  # @overload lookup_producer(scope, key)
  #   (see #lookup_proudcer_key)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param key [Object] an opaque object being the full key
  #
  # @overload lookup_producer(scope, type, name = '')
  #  (see #lookup_type)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param type [Puppet::Pops::Types::PObjectType], the type of what to lookup
  #   @param name [String], the name to use, defaults to empty string (for unnamed)
  #
  # @overload lookup_producer(scope, name)
  #  Lookup of Data type with given name.
  #   @see #lookup_type
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param name [String], the Data/name to lookup
  #
  # @return [Puppet::Pops::Binder::Producer] a producer
  #
  # @api public
  #
  def lookup_producer(scope, *args)
    # TODO: should return an object that may have additional ways of creating an instance
    # These are obviously not of value in the Puppet DSL (since methods cannot be invoked)
    # To support getting a producer that can behave as the Proc producers, the Proc should
    # be wrapped in an instance when user has not supplied a Producer class.
    raise ArgumentError, "lookup_producer should be called with two or three arguments, got: #{args.size()+1}" unless args.size <= 2
    case args[0]
    when Puppet::Pops::Types::PObjectType
      lookup_producer_type(scope, *args)
    when String
      raise ArgumentError, "lookup_producer of name should only pass the name" unless args.size == 1
      lookup_key(scope, key_factory.data_key(args[0]))
    else
      raise ArgumentError, "lookup_producer using a key should only pass a single key" unless args.size == 1
      lookup_producer_key(scope, args[0])
    end
  end

  # Looks up a Producer given an opaque binder key.
  # @returns [Puppet::Pops::Binder::Producer, nil] the bound producer, or nil if no such producer was found.
  # @api public
  #
  def lookup_producer_key(scope, key)
    producer(scope, entries[key])
  end

  # Looks up a Producer given a type/name key.
  # @note The result is not type checked (it cannot be until the producer has produced an instance).
  # @returns [Puppet::Pops::Binder::Producer, nil] the bound producer, or nil if no such producer was found
  # @api public
  #
  def lookup_producer_type(scope, type, name='')
    lookup_producer_key(named_key(type, name))
  end

  # TODO: Optional Producers; they should have a list of other producers (to be tested in turn for production) ??
  # Produces the value for the entry without performing any type checking
  # @return [nil] if the entry is nil (i.e. when not found)
  # @return [Object] the produced instance / value (non type-safe except for multibind contributions)
  #

  # Returns the producer for the entry
  # @return [Puppet::Pops::Binder::Producer] the entry's producer.
  #
  # @api private
  #
  def producer(scope, entry)
    return nil unless entry # not found
    unless entry.cached_producer
      entry.cached_producer = @@producer_visitor.visit_this(self, entry.binding.producer, scope, entry)
    end
    raise ArgumentError, "Injector entry without a producer TODO: detail" unless entry.cached_producer
    entry.cached_producer
  end

  # Creates a producer if given argument is a lambda, else returns the give producer
  # @return [Puppet::Pops::Binder::Producer] the given or producer wrapped lambda producer
  # @api private
  #
  def create_producer(lambda_or_producer)
    return lambda_or_producer if lambda_or_producer.is_a?(Puppet::Pops::Binder::Producer)
    return Puppet::Pops::Binder::LambdaProducer.new(lambda_or_producer)
  end

  # Returns the produced instance
  # @return [Object] the produced instance
  # @api private
  #
  def produce(scope, entry)
    return nil unless entry # not found
    producer(scope, entry).produce(scope)
  end

  # Called when producer is missing (e.g. a Multibinding)
  #
  def produce_NilClass(descriptor, scope, entry)
    # TODO: When the multibind has a nil producer it is not possible to flag it as being
    # singleton or not - in this case the collected content will need to determine its state
    # the issue is if a collected piece of content is dynamic as each multi lookup could potentially
    # be different
    #

    unless entry.binding.is_a?(Puppet::Pops::Binder::Bindings::Multibinding)
      raise ArgumentError, "Binding without producer detected (TODO: details)"
    end
    case entry.binding.type
    when Puppet::Pops::Types::PArrayType
      array_multibind_producer(entry.binding)
    when Puppet::Pops::Types::PArrayType
      hash_multibind_producer(entry.binding)
    else
      raise ArgumentError, "Unsupported multibind type, must be an array or hash type, but got: '#{entry.binding.type}"
    end
  end

  def produce_ArrayMultibindProducerDescriptor(descriptor, entry)
    p = array_multibind_producer(entry.binding)
    caching?(descriptor) ? singleton_producer(p.produce(scope)) : p
  end

  def produce_HashMultibindProducerDescriptor(descriptor, entry)
    p = hash_multibind_producer(entry.binding)
    caching?(descriptor) ? singleton_producer(p.produce(scope)) : p
  end

  # Produces a constant value
  # If not a singleton the value is deep-cloned (if not immutable) before returned.
  #
  def produce_ConstantProducerDescriptor(descriptor, scope, entry)
    x = if caching?(descriptor)
      deep_cloning_producer(descriptor.value)
    else
      singleton_producer(descriptor.value)
    end
    create_producer(x)
  end

  # Produces a new instance of the given class with given initialization arguments
  # If a singleton, the producer is asked to produce a single value and this is then considered a singleton.
  #
  def produce_InstanceProducer(descriptor, scope, entry)
    x = if caching?(descriptor)
      instantiating_producer.new(descriptor.class_name, *(descriptor.arguments))
    else
      singleton_producer(instantiating_producer(descriptor.class_name, *(descriptor.arguments)).produce(scope))
    end
    create_producer(x)
  end

  # Evaluates a contained expression. If this is a singleton, the evaluation is performed once.
  #
  def produce_EvaluatingProducerDescriptor(descriptor, scope, entry)
    x = if caching?(descriptor)
      evaluating_producer(descriptor.expr)
    else
      singleton_producer(evaluating_producer(descriptor.expr).produce(scope))
    end
    create_producer(x)
  end

  def produce_ProducerProducerDescriptor(descriptor, scope, entry)
    # Should produce an instance of the wanted producer
    instance_producer = @@producer_visitor.visit_this(self, descriptor.producer, scope, entry)
    p = Puppet::Pops::Binder::WrappingProducer.new(instance_producer)
    if caching?(descriptor)
      singleton_producer_producer(p.produce(scope))
    else
      p
    end
  end

  private

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

  def singleton_producer(value)
    create_producer(lambda {|scope| value })
  end

  def deep_cloning_producer(value)
    x = lambda do |scope|
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
    create_producer(x)
  end

  def instantiating_producer(class_name, *init_args)
    create_producer(lambda {|scope| Object.const_get(class_name).new(*init_args) } )
  end

  def evaluating_producer(expr)
    puppet3_ast = Puppet::Pops::Model::AstTransformer.new().transform(expr)
    create_producer(lambda { |scope| puppet_3_ast.evaluate(scope) })
  end

  def lookup_producer(type, name)
    create_producer( lambda { |scope| lookup_type(scope, type, name) })
  end

  # TODO: Support combinator lambda combinator => |$memo, $x| { $memo + $x }
  # @api private
  def array_multibind_producer(binding)
    contributions_key = key_factory.multibind_contributions_key(bindings.id)
    x = lambda do |scope|
      result = []
      lookup_key(scope, contributions_key).each do |k|
        val = lookup_key(scope, k)
        # typecheck
        # TODO: accepts array, or array of T
        unless type_calculator.assignable?(binding.type.element_type, val)
          raise ArgumentError, "Type Error: contribution #{entry.binding.name} does not match type of multibind #{binding.id}"
        end

        result << val.is_a?(Array) ? val : [ val ]
      end
      val
    end
    create_producer(x)
  end

  # TODO: Support combinator lambda combinator => |$key, $current, $value| { . . .}
  # @api private
  def hash_multibind_producer(binding)
    contributions_key = key_factory.multibind_contributions_key(bindings.id)
    x = lambda do |scope|
      result = {}
      lookup_key(scope, contributions_key).each do |k|
        # get the entry (its name is needed)
        entry = entries[k]
        raise ArgumentError, "Entry in multibind missing: #{k} for contributions: #{contributions_key}" unless entry
        # produce the value
        val = produce(scope, entry)
        # and typecheck it
        unless type_calculator.assignable?(binding.type.element_type, val)
          raise ArgumentError, "Type Error: contribution #{entry.binding.name} does not match type of multibind #{binding.id}"
        end
        # TODO: combinator lambda support
        result[entry.binding.name] = val
      end
      val
    end
    create_producer(x)
  end
end