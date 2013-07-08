# This module contains the varuious producers used by Puppet Bindings.
# The main class is {Puppet::Pops::Binder::Producers::Producer}
#
module Puppet::Pops::Binder::Producers
  # Producer is an abstract base class representing the base contract for a bound producer.
  # This class is used internally when an explicit producer is wanted (i.e. when looking up
  # a producer instead of an instance).
  #
  # Custom Producers
  # ----------------
  # The intent is also that this class is derived for custom producers that require additional
  # arguments when producing an instance. Such a custom producer may raise an error if called
  # with too few arguments, or may implement specific produce methods and always raise an
  # error on #produce indicating that this producer requires custom calls and that it can not
  # be used as an implicit producer.
  #
  # @abstract
  # @api public
  #
  class Producer
    # A Puppet 3 AST Lambda Expression
    attr_reader :transformer

    # Creates a Producer.
    # Derived classes should call this constructor to get support for transformer lambda.
    #
    # @option options [Puppet::Pops::Model::LambdaExpression] :transformer (nil) a transformer of produced value
    #
    def initialize(injector, binding, scope, options)
      if transformer_lambda = options[:transformer]
        raise ArgumentError, "Transformer must be a LambdaExpression" unless transformer_lambda.is_a?(Puppet::Pops::Model::LambdaExpression)
        raise ArgumentError, "Transformer lambda must take one argument; scope." unless transformer_lambda.parameters.size() == 1
        # NOTE: This depends on Puppet 3 AST Lambda
        @transformer = Puppet::Pops::Model::AstTransformer.new().transform(transformer_lambda)
      end
    end

    # Produces an instance.
    # @param scope [Puppet::Parser:Scope] the scope to use for evaluation
    # @param *args [Object] arguments to custom producers, always empty for implicit productions
    # @return [Object] the produced instance (should never be nil).
    #
    def produce(scope, *args)
      do_transformation(scope, internal_produce(scope))
    end

    # Returns the producer (self) after possibly having recreated an internal/wrapped producer.
    # This implementation returns `self`. A derived class may want to override this method
    # to perform initialization/refresh of its internal state. This method is called when
    # a producer is requested.
    # @see Puppet::Pops::Binder::ProducerProducer for an example of implementation.
    # @param scope [Puppet::Parser:Scope] the scope to use for evaluation
    # @return [Puppet::Pops::Binder::Producer] the producer to use
    #
    def producer(scope)
      self
    end

    protected

    # Derived classes should implement this method to do the production of a value
    def internal_produce(scope)
      raise NotImplementedError, "Producer-class '#{self.class.name}' should implement #internal_produce(scope)"
    end

    protected

    # Transforms the produced value if a transformer has been defined.
    # @param scope [Puppet::Parser::Scope] the scope used for evaluation
    # @param produced_value [Object, nil] the produced value (possibly nil)
    # @return [Object] the transformed value if a transformer is defined, else the given produced_value
    #
    def do_transformation(scope, produced_value)
      return produced_value unless transformer
      begin
        # CHEATING as the expressions should have access to array/hash concat/merge in array/hash
        current_parser = Puppet[:parser]
        Puppet[:parser] = 'future'
        produced_value = :undef if produced_value.nil?
        transformer.call(scope, produced_value)
      ensure
        # Stop CHEATING
        Puppet[:parser] = current_parser
      end
    end
  end

  # Abstract Producer holding a value
  class AbstractValueProducer < Producer
    attr_reader :value
    def initialize(injector, binding, scope, options)
      super
      # nil is ok here, as an abstract value producer may be used to signal "not found"
      @value = options[:value]
    end

  end

  # Produces the same/singlton value on each production
  class SingletonProducer < AbstractValueProducer
    protected
    def internal_produce(scope)
      value()
    end
  end

  # Produces a deep clone of its value on each production.
  #
  class DeepCloningProducer < AbstractValueProducer
    protected
    def internal_produce(scope)
      case value
      when Integer, Float, TrueClass, FalseClass, Symbol
        # These are immutable
        return value
      when String
        # ok if frozen, else fall through to default
        return value() if value.frozen?
      end
      # The default: serialize/deserialize to get a deep copy
      Marshal.load(Marshal.dump(value()))
    end
  end

  # This intermediate producer class remembers the injector and binding
  #
  class AbstractArgumentedProducer < Producer
    attr_reader :injector
    attr_reader :binding
    def initialize(injector, binding, scope, options)
      super
      @injector = injector
      @binding = binding
    end
  end

  class InstantiatingProducer < AbstractArgumentedProducer
    attr_reader :the_class
    attr_reader :init_args
    # @option options [String] :class_name The name of the class to create instance of
    # @option options [Array<Object>] :init_args ([]) Optional arguments to class constructor
    #
    def initialize(injector, binding, scope, options)
      # Better do this, even if a transformation of a created instance is kind of an odd thing to do, one can imagine
      # sending it to a function for further detailing.
      #
      super
      class_name = options[:class_name]
      raise ArgumentError, "Option 'class_name' must be given for an InstantiatingProducer" unless class_name
      # get class by name
      @the_class = injector.type_calculator.class_get(class_name)
      @init_args = options[:init_args] || []
    end

    protected

    # Performs initialization the same way as Assisted Inject does
    #
    def internal_produce(scope)
      if the_class.respond_to?(:inject)
        the_class.inject(injector, scope, binding, *init_args)
      else
        the_class.new(*init_args)
      end
    end
  end

  class FirstFoundProducer < Producer
    attr_reader :producers
    # @option options [Array<Puppet::Pops::Binder::Producer>] :producers list of producers to consult
    #
    def initialize(injector, binding, scope, options)
      super
      @producers = options[:producers]
      raise ArgumentError, "Option :producers' must be set to a list of producers." if @producers.nil?
      raise ArgumentError, "Given 'producers' option is not an Array" unless @producers.is_a?(Array)
    end

    protected

    def internal_produce(scope)
      # return the first produced value that is non-nil (unfortunately there is no such enumerable method)
      producers.reduce(nil) {|memo, p| break memo unless memo.nil?; p.produce(scope)}
    end
  end

  class EvaluatingProducer < Producer
    # A Puppet 3 AST Expression
    attr_reader :expression
    # @option options [Array<Puppet::Pops::Model::Expression>] :expression The expression to evaluate
    #
    def initialize(injector, binding, scope, options)
      super
      expr = options[:expression]
      raise ArgumentError, "Option 'expression' must be given to an EvaluatingProducer." unless expr
      @expression = Puppet::Pops::Model::AstTransformer.new().transform(expr)
    end

    def internal_produce(scope)
      begin
        # Must CHEAT as the expressions must have access to array/hash concat/merge
        current_parser = Puppet[:parser]
        Puppet[:parser] = 'future'
        expression.evaluate(scope)
      ensure
        # Stop cheating
        Puppet[:parser] = current_parser
      end
    end
  end

  class LookupProducer < AbstractArgumentedProducer
    attr_reader :type
    attr_reader :name
    # @option options [Puppet::Pops::Types::PObjectType] :type The type to lookup
    # @option options [String] :name ('') The name to lookup
    #
    def initialize(injector, binder, scope, options)
      super
      @type = options[:type]
      @name = options[:name] || ''
      raise ArgumentError, "Option 'type' must be given in a LookupProducer." unless @type
    end

    protected

    def internal_produce(scope)
      injector.lookup_type(scope, type, name)
    end
  end

  class LookupKeyProducer < LookupProducer
    attr_reader :key
    def initialize(injector, binder, scope, options)
      super
      @key = options[:key]
      raise ArgumentError, "Option 'key' must be given in a LookupKeyProducer." if key.nil?
    end

    protected

    def internal_produce(scope)

      result = super
      result.is_a?(Hash) ? result[key] : nil
    end
  end

  # Produces the given producer, then uses that producer.
  # @see ProducerProducer for the non singleton version
  #
  class SingletonProducerProducer < Producer
    attr_reader :value_producer
    def initialize(injector, binding, scope, options)
      super
      p = options[:producer_producer]
      raise ArgumentError, "Option :producer_producer must be given in a SingletonProducerProducer" unless p
      @value_producer = p.produce(scope)
    end

    protected

    def internal_produce(scope)
      value_producer.produce(scope)
    end
  end

  # A ProducerProducer creates a producer via another producer, and then uses this created producer
  # to produce values. This is useful for custom production of series of values.
  # On each request for a producer, this producer will reset its internal producer (i.e. restarting
  # the series).
  #
  # @param producer_producer [#produce(scope)] the producer of the producer
  #
  # @api public
  #
  class ProducerProducer < Producer
    attr_reader :producer_producer
    attr_reader :value_producer

    # Creates  new ProducerProducer given a producer.
    #
    # @option options [Puppet::Pops::Binder::Producer] :producer_producer a producer of a value producer
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      unless producer_producer = options[:producer_producer]
        raise ArgumentError, "The option :producer_producer must be set in a ProducerProducer"
      end
      raise ArgumentError, "Argument must be a Producer" unless producer_producer.is_a?(Producer)

      @producer_producer = producer_producer
      @value_producer = nil
    end

    # Updates the internal state to use a new instance of the wrapped producer.
    # @api public
    #
    def producer(scope)
      @value_producer = @producer_producer.produce(scope)
      self
    end

    protected

    # Produces a value after having created an instance of the wrapped producer (if not already created).
    # @api public
    #
    def internal_produce(scope, *args)
      producer() unless value_producer
      value_producer.produce(scope)
    end
  end

  class AssistedInjectProducer < Producer
    def initialize(injector, clazz)
      raise ArgumentError, "class must be given" unless clazz.is_a?(Class)

      @injector = injector
      @clazz = clazz
      @inst = nil
    end

    def produce(scope, *args)
      producer(scope, *args) unless @inst
      @inst
    end

    def producer(scope, *args)
      if @clazz.respond_to?(:inject)
        @inst = @clazz.inject(@injector, scope, nil, *args)
      else
        unless args.empty?
          raise ArgumentError, "Assisted Inject can not pass arguments to no-args constructor when there is no class inject method."
        end
        @inst = @clazz.new()
      end
      self
    end
  end

  class MultibindProducer < AbstractArgumentedProducer
    attr_reader :contributions_key
    def initialize(injector, binding, scope, options)
      super
      @contributions_key = injector.key_factory.multibind_contributions(binding.id)
    end
  end

  class ArrayMultibindProducer < MultibindProducer
    attr_reader :uniq
    attr_reader :flatten
    attr_reader :priority_on_named
    attr_reader :priority_on_unnamed

    # @option options [Boolean] :uniq (false) if collected result should be post-processed to contain only unique entries
    # @option options [Boolean] :flatten (false) if collected result should be post-processed so all contained arrays are flattened
    # @option options [Boolean] :priority_on_named (true) if highest precedented named element should win or if all should be included
    # @option options [Boolean] :priority_on_unnamed (false) if highest precedented unnamed element should win or if all should be included
    def initialize(injector, binding, scope, options)
      super
      @uniq = !!options[:uniq]
      @flatten = !!options[:flatten]
      @priority_on_named = options[:priority_on_named].nil? ? true : options[:priority_on_name]
      @priority_on_unnamed = !!options[:priority_on_unnamed]
    end

    protected

    def internal_produce(scope)
      seen = {}
      included_keys = []

      injector.get_contributions(scope, contributions_key).each do |element|
        key = element[0]
        entry = element[1]

        name = entry.binding.name
        existing = seen[name]
        empty_name = name.nil? || name.empty?
        if existing
          if empty_name && priority_on_unnamed
            next
          elsif !empty_name && priority_on_named
            next
          end
        else
          seen[name] = true
        end
        included_keys << key
      end
      result = included_keys.collect do |k|
        x = injector.lookup_key(scope, k)
        assert_type(binding(), injector.type_calculator(), x)
        x
      end

      result.flatten!() if flatten
      result.uniq! if uniq
      result
    end

    def assert_type(binding, tc, value)
      unless tc.instance?(binding.type.element_type, value) || tc.instance?(binding.type, value)
        raise ArgumentError, "Type Error: contribution #{binding.name} does not match type of multibind #{tc.label(binding.type)}"
      end
    end
  end

  class HashMultibindProducer < MultibindProducer
    attr_reader :conflict_resolution
    attr_reader :uniq
    attr_reader :flatten

    def initialize(injector, binding, scope, options)
      super
      @conflict_resolution = options[:conflict_resolution].nil? ? :error : options[:conflict_resolution]
      if conflict_resolution.to_s == 'append'
        # TODO: only applicable when result is Hash<Array> compatible
      end
      @uniq = !!options[:uniq]
      @flatten = !!options[:flatten]
      # TODO: uniq and flatten only apply when element type is compatible with array (and result is an array  if Data)
    end

    protected

    def internal_produce(scope)
      seen = {}
      included_entries = []

      injector.get_contributions(scope, contributions_key).each do |element|
        key = element[0]
        entry = element[1]

        name = entry.binding.name
        raise ArgumentError, "A Hash Multibind contribution to '#{binding.name}' must have a name." if name.nil? || name.empty?

        existing = seen[name]
        if existing
          case conflict_resolution.to_s
          when 'priority'
            next

          when 'error'
            raise ArgumentError, "Duplicate key contributed to Hash Multibinding '#{binding.name}', key: '#{name}'."

          end
        else
          seen[name] = true
        end
        included_entries << [key, entry]
      end 
      result = {}
      included_entries.each do |element|
        k = element[ 0 ]
        entry = element[ 1 ]
        x = injector.lookup_key(scope, k)
        name = entry.binding.name
        assert_type(binding(), injector.type_calculator(), name, x)
        if result[ name ]
          merge(result, name, result[ name ], x)
        else
        result[ name ] = conflict_resolution().to_s == 'append' ? [x] : x
        end
      end
      result
    end

    # TODO: Unfinished: handles append, but not merge
    #
    def merge(result, name, higher, lower)
      if conflict_resolution.to_s == 'append'
        # TODO: this is just append
        unless higher.is_a?(Array)
          higher = [higher]
        end
        tmp = higher + [lower]
        tmp.flatten! if flatten
        tmp.uniq! if uniq
        result[name] = tmp
      else
        raise ArgumentError, "TODO: Merge not implemented"
      end
    end

    def assert_type(binding, tc, key, value)
      unless tc.instance?(binding.type.key_type, key)
        raise ArgumentError, "Type Error: key contribution to #{binding.name}['#{key}'] is incompatible with key type: #{tc.label(binding.type)}"
      end

      if key.nil? || !key.is_a?(String) || key.empty?
        raise ArgumentError, "Entry contributing to multibind hash with id '#{binding.id}' must have a name."
      end

      unless tc.instance?(binding.type.element_type, value)
        raise ArgumentError, "Type Error: value contribution to #{binding.name}['#{key}'] is incompatible with value type: #{tc.label(binding.type)}"
      end
    end
  end

end