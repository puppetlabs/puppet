module Puppet::Pops
module Binder
# The injector is the "lookup service" class
#
# Initialization
# --------------
# The injector is initialized with a configured {Binder Binder}. The Binder instance contains a resolved set of
# `key => "binding information"` that is used to setup the injector.
#
# Lookup
# ------
# It is possible to lookup either the value, or a producer of the value. The {#lookup} method looks up a value, and the
# {#lookup_producer} looks up a producer.
# Both of these methods can be called with three different signatures; `lookup(key)`, `lookup(type, name)`, and `lookup(name)`,
# with the corresponding calls to obtain a producer; `lookup_producer(key)`, `lookup_producer(type, name)`, and `lookup_producer(name)`.
#
# It is possible to pass a block to {#lookup} and {#lookup_producer}, the block is passed the result of the lookup
# and the result of the block is returned as the value of the lookup. This is useful in order to provide a default value.
#
# @example Lookup with default value
#   injector.lookup('favourite_food') {|x| x.nil? ? 'bacon' : x }
#
# Singleton or Not
# ----------------
# The lookup of a value is always based on the lookup of a producer. For *singleton producers* this means that the value is
# determined by the first value lookup. Subsequent lookups via `lookup` or `lookup_producer` will produce the same instance.
#
# *Non singleton producers* will produce a new instance on each request for a value. For constant value producers this
# means that a new deep-clone is produced for mutable objects (but not for immutable objects as this is not needed).
# Custom producers should have non singleton behavior, or if this is not possible ensure that the produced result is
# immutable. (The behavior if a custom producer hands out a mutable value and this is mutated is undefined).
#
# Custom bound producers capable of producing a series of objects when bound as a singleton means that the producer
# is a singleton, not the value it produces. If such a producer is bound as non singleton, each `lookup` will get a new
# producer (hence, typically, restarting the series). However, the producer returned from `lookup_producer` will not
# recreate the producer on each call to `produce`; i.e. each `lookup_producer` returns a producer capable of returning
# a series of objects.
#
# @see Binder Binder, for details about how to bind keys to producers
# @see BindingsFactory BindingsFactory, for a convenient way to create a Binder and bindings
#
# Assisted Inject
# ---------------
# The injector supports lookup of instances of classes *even if the requested class is not explicitly bound*.
# This is possible for classes that have a zero argument `initialize` method, or that has a class method called
# `inject` that takes two arguments; `injector`, and `scope`.
# This is useful in ruby logic as a class can then use the given injector to inject details.
# An `inject` class method wins over a zero argument `initialize` in all cases.
#
# @example Using assisted inject
#   # Class with assisted inject support
#   class Duck
#     attr_reader :name, :year_of_birth
#
#     def self.inject(injector, scope, binding, *args)
#       # lookup default name and year of birth, and use defaults if not present
#       name = injector.lookup(scope,'default-duck-name') {|x| x ? x : 'Donald Duck' }
#       year_of_birth = injector.lookup(scope,'default-duck-year_of_birth') {|x| x ? x : 1934 }
#       self.new(name, year_of_birth)
#     end
#
#     def initialize(name, year_of_birth)
#       @name = name
#       @year_of_birth = year_of_birth
#     end
#   end
#
#   injector.lookup(scope, Duck)
#   # Produces a Duck named 'Donald Duck' or named after the binding 'default-duck-name' (and with similar treatment of
#   # year_of_birth).
# @see Producers::AssistedInjectProducer AssistedInjectProducer, for more details on assisted injection
#
# Access to key factory and type calculator
# -----------------------------------------
# It is important to use the same key factory, and type calculator as the binder. It is therefor possible to obtain
# these with the methods {#key_factory}, and {#type_calculator}.
#
# Special support for producers
# -----------------------------
# There is one method specially designed for producers. The {#get_contributions} method returns an array of all contributions
# to a given *contributions key*. This key is obtained from the {#key_factory} for a given multibinding. The returned set of
# contributed bindings is sorted in descending precedence order. Any conflicts, merges, etc. is performed by the multibinding
# producer configured for a multibinding.
#
# @api public
#
class Injector

  Producers = Producers

  def self.create_from_model(layered_bindings_model)
    self.new(Binder.new(layered_bindings_model))
  end

  def self.create_from_hash(name, key_value_hash)
    factory = BindingsFactory
    named_bindings = factory.named_bindings(name) { key_value_hash.each {|k,v| bind.name(k).to(v) }}
    layered_bindings = factory.layered_bindings(factory.named_layer(name+'-layer',named_bindings.model))
    self.new(Binder.new(layered_bindings))
  end

  # Creates an injector with a single bindings layer created with the given name, and the bindings
  # produced by the given block. The block is evaluated with self bound to a BindingsContainerBuilder.
  #
  # @example
  #   Injector.create('mysettings') do
  #     bind('name').to(42)
  #   end
  #
  # @api public
  #
  def self.create(name, &block)
    factory = BindingsFactory
    layered_bindings = factory.layered_bindings(factory.named_layer(name+'-layer',factory.named_bindings(name, &block).model))
    self.new(Binder.new(layered_bindings))
  end

  # Creates an overriding injector with a single bindings layer
  # created with the given name, and the bindings produced by the given block.
  # The block is evaluated with self bound to a BindingsContainerBuilder.
  #
  # @example
  #   an_injector.override('myoverrides') do
  #     bind('name').to(43)
  #   end
  #
  # @api public
  #
  def override(name, &block)
    factory = BindingsFactory
    layered_bindings = factory.layered_bindings(factory.named_layer(name+'-layer',factory.named_bindings(name, &block).model))
    self.class.new(Binder.new(layered_bindings, @impl.binder))
  end

  # Creates an overriding injector with bindings from a bindings model (a LayeredBindings) which
  # may consists of multiple layers of bindings.
  #
  # @api public
  #
  def override_with_model(layered_bindings)
    unless layered_bindings.is_a?(Bindings::LayeredBindings)
      raise ArgumentError, "Expected a LayeredBindings model, got '#{bindings_model.class}'"
    end
    self.class.new(Binder.new(layered_bindings, @impl.binder))
  end

  # Creates an overriding injector with a single bindings layer
  # created with the given name, and the bindings given in the key_value_hash
  # @api public
  #
  def override_with_hash(name, key_value_hash)
    factory = BindingsFactory
    named_bindings = factory.named_bindings(name) { key_value_hash.each {|k,v| bind.name(k).to(v) }}
    layered_bindings = factory.layered_bindings(factory.named_layer(name+'-layer',named_bindings.model))
    self.class.new(Binder.new(layered_bindings, @impl.binder))
  end

  # An Injector is initialized with a configured {Binder Binder}.
  #
  # @param configured_binder [Binder,nil] The configured binder containing effective bindings. A given value
  #   of nil creates an injector that returns or yields nil on all lookup requests.
  # @raise ArgumentError if the given binder is not fully configured
  #
  # @api public
  #
  def initialize(configured_binder, parent_injector = nil)
    if configured_binder.nil?
      @impl = Private::NullInjectorImpl.new()
    else
      @impl = Private::InjectorImpl.new(configured_binder, parent_injector)
    end
  end

  # The KeyFactory used to produce keys in this injector.
  # The factory is shared with the Binder to ensure consistent translation to keys.
  # A compatible type calculator can also be obtained from the key factory.
  # @return [KeyFactory] the key factory in use
  #
  # @api public
  #
  def key_factory()
    @impl.key_factory
  end

  # Returns the TypeCalculator in use for keys. The same calculator (as used for keys) should be used if there is a need
  # to check type conformance, or infer the type of Ruby objects.
  #
  # @return [Types::TypeCalculator] the type calculator that is in use for keys
  # @api public
  #
  def type_calculator()
    @impl.type_calculator()
  end

  # Lookup (a.k.a "inject") of a value given a key.
  # The lookup may be called with different parameters. This method is a convenience method that
  # dispatches to one of #lookup_key or #lookup_type depending on the arguments. It also provides
  # the ability to use an optional block that is called with the looked up value, or scope and value if the
  # block takes two parameters. This is useful to provide a default value or other transformations, calculations
  # based on the result of the lookup.
  #
  # @overload lookup(scope, key)
  #   (see #lookup_key)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param key [Object] an opaque object being the full key
  #
  # @overload lookup(scope, type, name = '')
  #   (see #lookup_type)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param type [Types::PAnyType] the type of what to lookup
  #   @param name [String] the name to use, defaults to empty string (for unnamed)
  #
  # @overload lookup(scope, name)
  #   Lookup of Data type with given name.
  #   @see #lookup_type
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param name [String] the Data/name to lookup
  #
  # @yield [value] passes the looked up value to an optional block and returns what this block returns
  # @yield [scope, value] passes scope and value to the block and returns what this block returns
  # @yieldparam scope [Puppet::Parser::Scope] the scope given to lookup
  # @yieldparam value [Object, nil] the looked up value or nil if nothing was found
  #
  # @raise [ArgumentError] if the block has an arity that is not 1 or 2
  #
  # @api public
  #
  def lookup(scope, *args, &block)
    @impl.lookup(scope, *args, &block)
  end

  # Looks up a (typesafe) value based on a type/name combination.
  # Creates a key for the type/name combination using a KeyFactory. Specialization of the Data type are transformed
  # to a Data key, and the result is type checked to conform with the given key.
  #
  # @param type [Types::PAnyType] the type to lookup as defined by Types::TypeFactory
  # @param name [String] the (optional for non `Data` types) name of the entry to lookup.
  #   The name may be an empty String (the default), but not nil. The name is required for lookup for subtypes of
  #   `Data`.
  # @return [Object, nil] the looked up bound object, or nil if not found (type conformance with given type is guaranteed)
  # @raise [ArgumentError] if the produced value does not conform with the given type
  #
  # @api public
  #
  def lookup_type(scope, type, name='')
    @impl.lookup_type(scope, type, name)
  end

  # Looks up the key and returns the entry, or nil if no entry is found.
  # Produced type is checked for type conformance with its binding, but not with the lookup key.
  # (This since all subtypes of PDataType are looked up using a key based on PDataType).
  # Use the Types::TypeCalculator#instance? method to check for conformance of the result
  # if this is wanted, or use #lookup_type.
  #
  # @param key [Object] lookup of key as produced by the key factory
  # @return [Object, nil] produced value of type that conforms with bound type (type conformance with key not guaranteed).
  # @raise [ArgumentError] if the produced value does not conform with the bound type
  #
  # @api public
  #
  def lookup_key(scope, key)
    @impl.lookup_key(scope, key)
  end

  # Lookup (a.k.a "inject") producer of a value given a key.
  # The producer lookup may be called with different parameters. This method is a convenience method that
  # dispatches to one of #lookup_producer_key or #lookup_producer_type depending on the arguments. It also provides
  # the ability to use an optional block that is called with the looked up producer, or scope and producer if the
  # block takes two parameters. This is useful to provide a default value, call a custom producer method,
  # or other transformations, calculations based on the result of the lookup.
  #
  # @overload lookup_producer(scope, key)
  #   (see #lookup_proudcer_key)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param key [Object] an opaque object being the full key
  #
  # @overload lookup_producer(scope, type, name = '')
  #   (see #lookup_type)
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param type [Types::PAnyType], the type of what to lookup
  #   @param name [String], the name to use, defaults to empty string (for unnamed)
  #
  # @overload lookup_producer(scope, name)
  #   Lookup of Data type with given name.
  #   @see #lookup_type
  #   @param scope [Puppet::Parser::Scope] the scope to use for evaluation
  #   @param name [String], the Data/name to lookup
  #
  # @return [Producers::Producer, Object, nil] a producer, or what the optional block returns
  #
  # @yield [producer] passes the looked up producer to an optional block and returns what this block returns
  # @yield [scope, producer] passes scope and producer to the block and returns what this block returns
  # @yieldparam producer [Producers::Producer, nil] the looked up producer or nil if nothing was bound
  # @yieldparam scope [Puppet::Parser::Scope] the scope given to lookup
  #
  # @raise [ArgumentError] if the block has an arity that is not 1 or 2
  #
  # @api public
  #
  def lookup_producer(scope, *args, &block)
    @impl.lookup_producer(scope, *args, &block)
  end

  # Looks up a Producer given an opaque binder key.
  # @return [Producers::Producer, nil] the bound producer, or nil if no such producer was found.
  #
  # @api public
  #
  def lookup_producer_key(scope, key)
    @impl.lookup_producer_key(scope, key)
  end

  # Looks up a Producer given a type/name key.
  # @note The result is not type checked (it cannot be until the producer has produced an instance).
  # @return [Producers::Producer, nil] the bound producer, or nil if no such producer was found
  #
  # @api public
  #
  def lookup_producer_type(scope, type, name='')
    @impl.lookup_producer_type(scope, type, name)
  end

  # Returns the contributions to a multibind given its contribution key (as produced by the KeyFactory).
  # This method is typically used by multibind value producers, but may be used for introspection of the injector's state.
  #
  # @param scope [Puppet::Parser::Scope] the scope to use
  # @param contributions_key [Object] Opaque key as produced by KeyFactory as the contributions key for a multibinding
  # @return [Array<InjectorEntry>] the contributions sorted in deecending order of precedence
  #
  # @api public
  #
  def get_contributions(scope, contributions_key)
    @impl.get_contributions(scope, contributions_key)
  end

  # Returns an Injector that returns (or yields) nil on all lookups, and produces an empty structure for contributions
  # This method is intended for testing purposes.
  #
  def self.null_injector
    self.new(nil)
  end

# The implementation of the Injector is private.
# @see Injector The public API this module implements.
# @api private
#
module Private

  # This is a mocking "Null" implementation of Injector. It never finds anything
  # @api private
  class NullInjectorImpl
    attr_reader :entries
    attr_reader :key_factory
    attr_reader :type_calculator

    def initialize
      @entries = []
      @key_factory = KeyFactory.new()
      @type_calculator = Types::TypeCalculator.singleton
    end

    def lookup(scope, *args, &block)
      raise ArgumentError, "lookup should be called with two or three arguments, got: #{args.size()+1}" unless args.size.between?(1,2)
      # call block with result if given
      if block
        case block.arity
        when 1
          block.call(nil)
        when 2
          block.call(scope, nil)
        else
          raise ArgumentError, "The block should have arity 1 or 2"
        end
      else
        val
      end
    end

    # @api private
    def binder
      nil
    end

    # @api private
    def lookup_key(scope, key)
      nil
    end

    # @api private
    def lookup_producer(scope, *args, &block)
      lookup(scope, *args, &block)
    end

    # @api private
    def lookup_producer_key(scope, key)
      nil
    end

    # @api private
    def lookup_producer_type(scope, type, name='')
      nil
    end

    def get_contributions()
      []
    end
  end

  # @api private
  #
  class InjectorImpl
    # Hash of key => InjectorEntry
    # @api private
    #
    attr_reader :entries

    attr_reader :key_factory

    attr_reader :type_calculator

    attr_reader :binder

    def initialize(configured_binder, parent_injector = nil)
      @binder = configured_binder
      @parent = parent_injector

      # TODO: Different error message
      raise ArgumentError, "Given Binder is not configured" unless configured_binder #&& configured_binder.configured?()
      @entries             = configured_binder.injector_entries()

      # It is essential that the injector uses the same key factory as the binder since keys must be
      # represented the same (but still opaque) way.
      #
      @key_factory         = configured_binder.key_factory()
      @type_calculator     = Types::TypeCalculator.singleton
      @@transform_visitor ||= Visitor.new(nil,"transform", 2,  2)
      @recursion_lock = [ ]
    end

    # @api private
    def lookup(scope, *args, &block)
      raise ArgumentError, "lookup should be called with two or three arguments, got: #{args.size()+1}" unless args.size.between?(1,2)

      val = case args[ 0 ]

      when Types::PAnyType
        lookup_type(scope, *args)

      when String
        raise ArgumentError, "lookup of name should only pass the name" unless args.size == 1
        lookup_key(scope, key_factory.data_key(args[ 0 ]))

      else
        raise ArgumentError, 'lookup using a key should only pass a single key' unless args.size == 1
        lookup_key(scope, args[ 0 ])
      end

      # call block with result if given
      if block
        case block.arity
        when 1
          block.call(val)
        when 2
          block.call(scope, val)
        else
          raise ArgumentError, "The block should have arity 1 or 2"
        end
      else
        val
      end
    end

    # Produces a key for a type/name combination.
    # @api private
    def named_key(type, name)
      key_factory.named_key(type, name)
    end

    # Produces a key for a PDataType/name combination
    # @api private
    def data_key(name)
      key_factory.data_key(name)
    end

    # @api private
    def lookup_type(scope, type, name='')
      val = lookup_key(scope, named_key(type, name))
      return nil if val.nil?
      unless type_calculator.instance?(type, val)
        raise ArgumentError, "Type error: incompatible type, #{type_error_detail(type, val)}"
      end
      val
    end

    # @api private
    def type_error_detail(expected, actual)
      actual_t = type_calculator.infer(actual)
      "expected: #{expected}, got: #{actual_t}"
    end

    # @api private
    def lookup_key(scope, key)
      if @recursion_lock.include?(key)
        raise ArgumentError, "Lookup loop detected for key: #{key}"
      end
      begin
        @recursion_lock.push(key)
        case entry = get_entry(key)
        when NilClass
          @parent ? @parent.lookup_key(scope, key) : nil

        when InjectorEntry
          val = produce(scope, entry)
          return nil if val.nil?
          unless type_calculator.instance?(entry.binding.type, val)
            raise "Type error: incompatible type returned by producer, #{type_error_detail(entry.binding.type, val)}"
          end
          val
        when Producers::AssistedInjectProducer
          entry.produce(scope)
        else
          # internal, direct entries
          entry
        end
      ensure
        @recursion_lock.pop()
      end
    end

    # Should be used to get entries as it converts missing entries to NotFound entries or AssistedInject entries
    #
    # @api private
    def get_entry(key)
      case entry = entries[ key ]
      when NilClass
        # not found, is this an assisted inject?
        if clazz = assistable_injected_class(key)
          entry = Producers::AssistedInjectProducer.new(self, clazz)
          entries[ key ] = entry
        else
          entries[ key ] = NotFound.new()
          entry = nil
        end
      when NotFound
        entry = nil
      end
      entry
    end

    # Returns contributions to a multibind in precedence order; highest first.
    # Returns an Array on the form [ [key, entry], [key, entry]] where the key is intended to be used to lookup the value
    # (or a producer) for that entry.
    # @api private
    def get_contributions(scope, contributions_key)
      result = {}
      return [] unless contributions = lookup_key(scope, contributions_key)
      contributions.each { |k| result[k] = get_entry(k) }
      result.sort {|a, b| a[0] <=> b[0] }
    end

    # Produces an injectable class given a key, or nil if key does not represent an injectable class
    # @api private
    #
    def assistable_injected_class(key)
      kt = key_factory.get_type(key)
      return nil unless kt.is_a?(Types::PRuntimeType) && kt.runtime == :ruby && !key_factory.is_named?(key)
      type_calculator.injectable_class(kt)
    end

    def lookup_producer(scope, *args, &block)
      raise ArgumentError, "lookup_producer should be called with two or three arguments, got: #{args.size()+1}" unless args.size <= 2

      p = case args[ 0 ]
      when Types::PAnyType
        lookup_producer_type(scope, *args)

      when String
        raise ArgumentError, "lookup_producer of name should only pass the name" unless args.size == 1
        lookup_producer_key(scope, key_factory.data_key(args[ 0 ]))

      else
        raise ArgumentError, "lookup_producer using a key should only pass a single key" unless args.size == 1
        lookup_producer_key(scope, args[ 0 ])
      end

      # call block with result if given
      if block
        case block.arity
        when 1
          block.call(p)
        when 2
          block.call(scope, p)
        else
          raise ArgumentError, "The block should have arity 1 or 2"
        end
      else
        p
      end
    end

    # @api private
    def lookup_producer_key(scope, key)
      if @recursion_lock.include?(key)
        raise ArgumentError, "Lookup loop detected for key: #{key}"
      end
      begin
        @recursion_lock.push(key)
        producer(scope, get_entry(key), :multiple_use)
      ensure
        @recursion_lock.pop()
      end
    end

    # @api private
    def lookup_producer_type(scope, type, name='')
      lookup_producer_key(scope, named_key(type, name))
    end

    # Returns the producer for the entry
    # @return [Producers::Producer] the entry's producer.
    #
    # @api private
    #
    def producer(scope, entry, use)
      return nil unless entry # not found
      return entry.producer(scope) if entry.is_a?(Producers::AssistedInjectProducer)
      unless entry.cached_producer
        entry.cached_producer = transform(entry.binding.producer, scope, entry)
      end
      unless entry.cached_producer
        raise ArgumentError, "Injector entry without a producer #{format_binding(entry.binding)}"
      end
      entry.cached_producer.producer(scope)
    end

    # @api private
    def transform(producer_descriptor, scope, entry)
      @@transform_visitor.visit_this_2(self, producer_descriptor, scope, entry)
    end

    # Returns the produced instance
    # @return [Object] the produced instance
    # @api private
    #
    def produce(scope, entry)
      return nil unless entry # not found
      producer(scope, entry, :single_use).produce(scope)
    end

    # @api private
    def named_arguments_to_hash(named_args)
      nb = named_args.nil? ? [] : named_args
      result = {}
      nb.each {|arg| result[ :"#{arg.name}" ] = arg.value }
      result
    end

    # @api private
    def merge_producer_options(binding, options)
      named_arguments_to_hash(binding.producer_args).merge(options)
    end

    # @api private
    def format_binding(b)
      Binder.format_binding(b)
    end

    # Handles a  missing producer (which is valid for a Multibinding where one is selected automatically)
    # @api private
    #
    def transform_NilClass(descriptor, scope, entry)
      unless entry.binding.is_a?(Bindings::Multibinding)
        raise ArgumentError, "Binding without producer detected, #{format_binding(entry.binding)}"
      end
      case entry.binding.type
      when Types::PArrayType
        transform(Bindings::ArrayMultibindProducerDescriptor.new(), scope, entry)
      when Types::PHashType
        transform(Bindings::HashMultibindProducerDescriptor.new(), scope, entry)
      else
        raise ArgumentError, "Unsupported multibind type, must be an array or hash type, #{format_binding(entry.binding)}"
      end
    end

    # @api private
    def transform_ArrayMultibindProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::ArrayMultibindProducer, descriptor, scope, entry, named_arguments_to_hash(entry.binding.producer_args))
    end

    # @api private
    def transform_HashMultibindProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::HashMultibindProducer, descriptor, scope, entry, named_arguments_to_hash(entry.binding.producer_args))
    end

    # @api private
    def transform_ConstantProducerDescriptor(descriptor, scope, entry)
      producer_class = singleton?(descriptor) ? Producers::SingletonProducer : Producers::DeepCloningProducer
      producer_class.new(self, entry.binding, scope, merge_producer_options(entry.binding, {:value => descriptor.value}))
    end

    # @api private
    def transform_InstanceProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::InstantiatingProducer, descriptor, scope, entry,
        merge_producer_options(entry.binding, {:class_name => descriptor.class_name, :init_args => descriptor.arguments}))
    end

    # @api private
    def transform_EvaluatingProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::EvaluatingProducer, descriptor, scope, entry,
        merge_producer_options(entry.binding, {:expression => descriptor.expression}))
    end

    # @api private
    def make_producer(clazz, descriptor, scope, entry, options)
      singleton_wrapped(descriptor, scope, entry, clazz.new(self, entry.binding, scope, options))
    end

    # @api private
    def singleton_wrapped(descriptor, scope, entry, producer)
      return producer unless singleton?(descriptor)
      Producers::SingletonProducer.new(self, entry.binding, scope,
        merge_producer_options(entry.binding, {:value => producer.produce(scope)}))
    end

    # @api private
    def transform_ProducerProducerDescriptor(descriptor, scope, entry)
      p = transform(descriptor.producer, scope, entry)
      clazz = singleton?(descriptor) ? Producers::SingletonProducerProducer : Producers::ProducerProducer
      clazz.new(self, entry.binding, scope, merge_producer_options(entry.binding,
        merge_producer_options(entry.binding, { :producer_producer => p })))
    end

    # @api private
    def transform_LookupProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::LookupProducer, descriptor, scope, entry,
        merge_producer_options(entry.binding, {:type => descriptor.type, :name => descriptor.name}))
    end

    # @api private
    def transform_HashLookupProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::LookupKeyProducer, descriptor, scope,  entry,
        merge_producer_options(entry.binding, {:type => descriptor.type, :name => descriptor.name, :key => descriptor.key}))
    end

    # @api private
    def transform_NonCachingProducerDescriptor(descriptor, scope, entry)
      # simply delegates to the wrapped producer
      transform(descriptor.producer, scope, entry)
    end

    # @api private
    def transform_FirstFoundProducerDescriptor(descriptor, scope, entry)
      make_producer(Producers::FirstFoundProducer, descriptor, scope, entry,
        merge_producer_options(entry.binding, {:producers => descriptor.producers.collect {|p| transform(p, scope, entry) }}))
    end

    # @api private
    def singleton?(descriptor)
      ! descriptor.eContainer().is_a?(Bindings::NonCachingProducerDescriptor)
    end

    # Special marker class used in entries
    # @api private
    class NotFound
    end
  end
end
end
end
end

