module Puppet::Pops
module Binder
# This module contains the various producers used by Puppet Bindings.

# The main (abstract) class is {Producers::Producer} which documents the
# Producer API and serves as a base class for all other producers.
# It is required that custom producers inherit from this producer (directly or indirectly).
#
# The selection of a Producer is typically performed by the Innjector when it configures itself
# from a Bindings model where a {Bindings::ProducerDescriptor} describes
# which producer to use. The configuration uses this to create the concrete producer.
# It is possible to describe that a particular producer class is to be used, and also to describe that
# a custom producer (derived from Producer) should be used. This is available for both regular
# bindings as well as multi-bindings.
#
#
# @api public
#
module Producers
  # Producer is an abstract base class representing the base contract for a bound producer.
  # Typically, when a lookup is performed it is the value that is returned (via a producer), but
  # it is also possible to lookup the producer, and ask it to produce the value (the producer may
  # return a series of values, which makes this especially useful).
  #
  # When looking up a producer, it is of importance to only use the API of the Producer class
  # unless it is known that a particular custom producer class has been bound.
  #
  # Custom Producers
  # ----------------
  # The intent is that this class is derived for custom producers that require additional
  # options/arguments when producing an instance. Such a custom producer may raise an error if called
  # with too few arguments, or may implement specific `produce` methods and always raise an
  # error on #produce indicating that this producer requires custom calls and that it can not
  # be used as an implicit producer.
  #
  # Features of Producer
  # --------------------
  # The Producer class is abstract, but offers the ability to transform the produced result
  # by passing the option `:transformer` which should be a Puppet Lambda Expression taking one argument
  # and producing the transformed (wanted) result.
  #
  # @abstract
  # @api public
  #
  class Producer
    # A Puppet 3 AST Lambda Expression
    # @api public
    #
    attr_reader :transformer

    # Creates a Producer.
    # Derived classes should call this constructor to get support for transformer lambda.
    #
    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @api public
    #
    def initialize(injector, binding, scope, options)
      if transformer_lambda = options[:transformer]
        if transformer_lambda.is_a?(Proc)
          raise ArgumentError, "Transformer Proc must take one argument; value." unless transformer_lambda.arity == 1
          @transformer = transformer_lambda
        else
          raise ArgumentError, "Transformer must be a LambdaExpression" unless transformer_lambda.is_a?(Model::LambdaExpression)
          raise ArgumentError, "Transformer lambda must take one argument; value." unless transformer_lambda.parameters.size() == 1
          @transformer = Parser::EvaluatingParser.new.closure(transformer_lambda, scope)
        end
      end
    end

    # Produces an instance.
    # @param scope [Puppet::Parser:Scope] the scope to use for evaluation
    # @param args [Object] arguments to custom producers, always empty for implicit productions
    # @return [Object] the produced instance (should never be nil).
    # @api public
    #
    def produce(scope, *args)
      do_transformation(scope, internal_produce(scope))
    end

    # Returns the producer after possibly having recreated an internal/wrapped producer.
    # This implementation returns `self`. A derived class may want to override this method
    # to perform initialization/refresh of its internal state. This method is called when
    # a producer is requested.
    # @see ProducerProducer for an example of implementation.
    # @param scope [Puppet::Parser:Scope] the scope to use for evaluation
    # @return [Producer] the producer to use
    # @api public
    #
    def producer(scope)
      self
    end

    protected

    # Derived classes should implement this method to do the production of a value
    # @param scope [Puppet::Parser::Scope] the scope to use when performing lookup and evaluation
    # @raise [NotImplementedError] this implementation always raises an error
    # @abstract
    # @api private
    #
    def internal_produce(scope)
      raise NotImplementedError, "Producer-class '#{self.class.name}' should implement #internal_produce(scope)"
    end

    # Transforms the produced value if a transformer has been defined.
    # @param scope [Puppet::Parser::Scope] the scope used for evaluation
    # @param produced_value [Object, nil] the produced value (possibly nil)
    # @return [Object] the transformed value if a transformer is defined, else the given `produced_value`
    # @api private
    #
    def do_transformation(scope, produced_value)
      return produced_value unless transformer
      transformer.call(produced_value)
    end
  end

  # Abstract Producer holding a value
  # @abstract
  # @api public
  #
  class AbstractValueProducer < Producer

    # @api public
    attr_reader :value

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Model::LambdaExpression, nil] :value (nil) the value to produce
    # @api public
    #
   def initialize(injector, binding, scope, options)
      super
      # nil is ok here, as an abstract value producer may be used to signal "not found"
      @value = options[:value]
    end
  end

  # Produces the same/singleton value on each production
  # @api public
  #
  class SingletonProducer < AbstractValueProducer
    protected

    # @api private
    def internal_produce(scope)
      value()
    end
  end

  # Produces a deep clone of its value on each production.
  # @api public
  #
  class DeepCloningProducer < AbstractValueProducer
    protected

    # @api private
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

  # This abstract producer class remembers the injector and binding.
  # @abstract
  # @api public
  #
  class AbstractArgumentedProducer < Producer

    # @api public
    attr_reader :injector

    # @api public
    attr_reader :binding

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      @injector = injector
      @binding = binding
    end
  end

  # @api public
  class InstantiatingProducer < AbstractArgumentedProducer

    # @api public
    attr_reader :the_class

    # @api public
    attr_reader :init_args

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [String] :class_name The name of the class to create instance of
    # @option options [Array<Object>] :init_args ([]) Optional arguments to class constructor
    # @api public
    #
    def initialize(injector, binding, scope, options)
      # Better do this, even if a transformation of a created instance is kind of an odd thing to do, one can imagine
      # sending it to a function for further detailing.
      #
      super
      class_name = options[:class_name]
      raise ArgumentError, "Option 'class_name' must be given for an InstantiatingProducer" unless class_name
      # get class by name
      @the_class = Types::ClassLoader.provide(class_name)
      @init_args = options[:init_args] || []
      raise ArgumentError, "Can not load the class #{class_name} specified in binding named: '#{binding.name}'" unless @the_class
    end

    protected

    # Performs initialization the same way as Assisted Inject does (but handle arguments to
    # constructor)
    # @api private
    #
    def internal_produce(scope)
      result = nil
      # A class :inject method wins over an instance :initialize if it is present, unless a more specific
      # constructor exists. (i.e do not pick :inject from superclass if class has a constructor).
      #
      if the_class.respond_to?(:inject)
        inject_method = the_class.method(:inject)
        initialize_method = the_class.instance_method(:initialize)
        if inject_method.owner <= initialize_method.owner
          result = the_class.inject(injector, scope, binding, *init_args)
        end
      end
      if result.nil?
        result = the_class.new(*init_args)
      end
      result
    end
  end

  # @api public
  class FirstFoundProducer < Producer
    # @api public
    attr_reader :producers

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Array<Producers::Producer>] :producers list of producers to consult. Required.
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      @producers = options[:producers]
      raise ArgumentError, "Option :producers' must be set to a list of producers." if @producers.nil?
      raise ArgumentError, "Given 'producers' option is not an Array" unless @producers.is_a?(Array)
    end

    protected

    # @api private
    def internal_produce(scope)
      # return the first produced value that is non-nil (unfortunately there is no such enumerable method)
      producers.reduce(nil) {|memo, p| break memo unless memo.nil?; p.produce(scope)}
    end
  end

  # Evaluates a Puppet Expression and returns the result.
  # This is typically used for strings with interpolated expressions.
  # @api public
  #
  class EvaluatingProducer < Producer
    # A Puppet 3 AST Expression
    # @api public
    #
    attr_reader :expression

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Array<Model::Expression>] :expression The expression to evaluate
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      @expression = options[:expression]
      raise ArgumentError, "Option 'expression' must be given to an EvaluatingProducer." unless @expression
    end

    # @api private
    def internal_produce(scope)
      Parser::EvaluatingParser.new.evaluate(scope, expression)
    end
  end

  # @api public
  class LookupProducer < AbstractArgumentedProducer

    # @api public
    attr_reader :type

    # @api public
    attr_reader :name

    # @param injector [Injector] The injector where the lookup originates
    # @param binder [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Types::PAnyType] :type The type to lookup
    # @option options [String] :name ('') The name to lookup
    # @api public
    #
    def initialize(injector, binder, scope, options)
      super
      @type = options[:type]
      @name = options[:name] || ''
      raise ArgumentError, "Option 'type' must be given in a LookupProducer." unless @type
    end

    protected

    # @api private
    def internal_produce(scope)
      injector.lookup_type(scope, type, name)
    end
  end

  # @api public
  class LookupKeyProducer < LookupProducer

    # @api public
    attr_reader :key

    # @param injector [Injector] The injector where the lookup originates
    # @param binder [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Types::PAnyType] :type The type to lookup
    # @option options [String] :name ('') The name to lookup
    # @option options [Types::PAnyType] :key The key to lookup in the hash
    # @api public
    #
    def initialize(injector, binder, scope, options)
      super
      @key = options[:key]
      raise ArgumentError, "Option 'key' must be given in a LookupKeyProducer." if key.nil?
    end

    protected

    # @api private
    def internal_produce(scope)

      result = super
      result.is_a?(Hash) ? result[key] : nil
    end
  end

  # Produces the given producer, then uses that producer.
  # @see ProducerProducer for the non singleton version
  # @api public
  #
  class SingletonProducerProducer < Producer

    # @api public
    attr_reader :value_producer

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Model::LambdaExpression] :producer_producer a producer of a value producer (required)
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      p = options[:producer_producer]
      raise ArgumentError, "Option :producer_producer must be given in a SingletonProducerProducer" unless p
      @value_producer = p.produce(scope)
    end

    protected

    # @api private
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

    # @api public
    attr_reader :producer_producer

    # @api public
    attr_reader :value_producer

    # Creates  new ProducerProducer given a producer.
    #
    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Producer] :producer_producer a producer of a value producer (required)
    #
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
    # @api private
    #
    def internal_produce(scope, *args)
      producer() unless value_producer
      value_producer.produce(scope)
    end
  end

  # This type of producer should only be created by the Injector.
  #
  # @api private
  #
  class AssistedInjectProducer < Producer
    # An Assisted Inject Producer is created when a lookup is made of a type that is
    # not bound. It does not support a transformer lambda.
    # @note This initializer has a different signature than all others. Do not use in regular logic.
    # @api private
    #
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

    # @api private
    def producer(scope, *args)
      @inst = nil
      # A class :inject method wins over an instance :initialize if it is present, unless a more specific zero args
      # constructor exists. (i.e do not pick :inject from superclass if class has a zero args constructor).
      #
      if @clazz.respond_to?(:inject)
        inject_method = @clazz.method(:inject)
        initialize_method = @clazz.instance_method(:initialize)
        if inject_method.owner <= initialize_method.owner || initialize_method.arity != 0
          @inst = @clazz.inject(@injector, scope, nil, *args)
        end
      end
      if @inst.nil?
        unless args.empty?
          raise ArgumentError, "Assisted Inject can not pass arguments to no-args constructor when there is no class inject method."
        end
        @inst = @clazz.new()
      end
      self
    end
  end

  # Abstract base class for multibind producers.
  # Is suitable as base class for custom implementations of multibind producers.
  # @abstract
  # @api public
  #
  class MultibindProducer < AbstractArgumentedProducer
    attr_reader :contributions_key

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    #
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      @contributions_key = injector.key_factory.multibind_contributions(binding.id)
    end

    # @param expected [Array<Types::PAnyType>, Types::PAnyType] expected type or types
    # @param actual [Object, Types::PAnyType> the actual value (or its type)
    # @return [String] a formatted string for inclusion as detail in an error message
    # @api private
    #
    def type_error_detail(expected, actual)
      tc = injector.type_calculator
      expected = [expected] unless expected.is_a?(Array)
      actual_t = tc.is_ptype?(actual) ? actual : tc.infer(actual)
      expstrs = expected.collect {|t| t.to_s }
      "expected: #{expstrs.join(', or ')}, got: #{actual_t}"
    end
  end

  # A configurable multibind producer for Array type multibindings.
  #
  # This implementation collects all contributions to the multibind and then combines them using the following rules:
  #
  # - all *unnamed* entries are added unless the option `:priority_on_unnamed` is set to true, in which case the unnamed
  #   contribution with the highest priority is added, and the rest are ignored (unless they have the same priority in which
  #   case an error is raised).
  # - all *named* entries are handled the same way as *unnamed* but the option `:priority_on_named` controls their handling.
  # - the option `:uniq` post processes the result to only contain unique entries
  # - the option `:flatten` post processes the result by flattening all nested arrays.
  # - If both `:flatten` and `:uniq` are true, flattening is done first.
  #
  # @note
  #   Collection accepts elements that comply with the array's element type, or the entire type (i.e. Array[element_type]).
  #   If the type is restrictive - e.g. Array[String] and an Array[String] is contributed, the result will not be type
  #   compliant without also using the `:flatten` option, and a type error will be raised. For an array with relaxed typing
  #   i.e. Array[Data], it is valid to produce a result such as `['a', ['b', 'c'], 'd']` and no flattening is required
  #   and no error is raised (but using the array needs to be aware of potential array, non-array entries.
  #   The use of the option `:flatten` controls how the result is flattened.
  #
  # @api public
  #
  class ArrayMultibindProducer < MultibindProducer

    # @return [Boolean] whether the result should be made contain unique (non-equal) entries or not
    # @api public
    attr_reader :uniq

    # @return [Boolean, Integer] If result should be flattened (true), or not (false), or flattened to given level (0 = none, -1 = all)
    # @api public
    attr_reader :flatten

    # @return [Boolean] whether priority should be considered for named contributions
    # @api public
    attr_reader :priority_on_named

    # @return [Boolean] whether priority should be considered for unnamed contributions
    # @api public
    attr_reader :priority_on_unnamed

    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Boolean] :uniq (false) if collected result should be post-processed to contain only unique entries
    # @option options [Boolean, Integer] :flatten (false) if collected result should be post-processed so all contained arrays
    #   are flattened. May be set to an Integer value to indicate the level of recursion (-1 is endless, 0 is none).
    # @option options [Boolean] :priority_on_named (true) if highest precedented named element should win or if all should be included
    # @option options [Boolean] :priority_on_unnamed (false) if highest precedented unnamed element should win or if all should be included
    # @api public
    #
    def initialize(injector, binding, scope, options)
      super
      @uniq = !!options[:uniq]
      @flatten = options[:flatten]
      @priority_on_named = options[:priority_on_named].nil? ? true : options[:priority_on_name]
      @priority_on_unnamed = !!options[:priority_on_unnamed]

      case @flatten
      when Integer
      when true
        @flatten = -1
      when false
        @flatten = nil
      when NilClass
        @flatten = nil
      else
        raise ArgumentError, "Option :flatten must be nil, Boolean, or an integer value" unless @flatten.is_a?(Integer)
      end
    end

    protected

    # @api private
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
            if (seen[name] <=> entry) >= 0
              raise ArgumentError, "Duplicate key (same priority) contributed to Array Multibinding '#{binding.name}' with unnamed entry."
            end
            next
          elsif !empty_name && priority_on_named
            if (seen[name] <=> entry) >= 0
              raise ArgumentError, "Duplicate key (same priority) contributed to Array Multibinding '#{binding.name}', key: '#{name}'."
            end
            next
          end
        else
          seen[name] = entry
        end
        included_keys << key
      end
      result = included_keys.collect do |k|
        x = injector.lookup_key(scope, k)
        assert_type(binding(), injector.type_calculator(), x)
        x
      end

      result.flatten!(flatten) if flatten
      result.uniq! if uniq
      result
    end

    # @api private
    def assert_type(binding, tc, value)
      infered = tc.infer(value)
      unless tc.assignable?(binding.type.element_type, infered) || tc.assignable?(binding.type, infered)
        raise ArgumentError, ["Type Error: contribution to '#{binding.name}' does not match type of multibind, ",
          "#{type_error_detail([binding.type.element_type, binding.type], value)}"].join()
      end
    end
  end

  # @api public
  class HashMultibindProducer < MultibindProducer

    # @return [Symbol] One of `:error`, `:merge`, `:append`, `:priority`, `:ignore`
    # @api public
    attr_reader :conflict_resolution

    # @return [Boolean]
    # @api public
    attr_reader :uniq

    # @return [Boolean, Integer] Flatten all if true, or none if false, or to given level (0 = none, -1 = all)
    # @api public
    attr_reader :flatten

    # The hash multibind producer provides options to control conflict resolution.
    # By default, the hash is produced using `:priority` resolution - the highest entry is selected, the rest are
    # ignored unless they have the same priority which is an error.
    #
    # @param injector [Injector] The injector where the lookup originates
    # @param binding [Bindings::Binding, nil] The binding using this producer
    # @param scope [Puppet::Parser::Scope] The scope to use for evaluation
    # @option options [Model::LambdaExpression] :transformer (nil) a transformer of produced value
    # @option options [Symbol, String] :conflict_resolution (:priority) One of `:error`, `:merge`, `:append`, `:priority`, `:ignore`
    #   <ul><li> `ignore` the first found highest priority contribution is used, the rest are ignored</li>
    #   <li>`error` any duplicate key is an error</li>
    #   <li>`append` element type must be compatible with Array, makes elements be arrays and appends all found</li>
    #   <li>`merge` element type must be compatible with hash, merges hashes with retention of highest priority hash content</li>
    #   <li>`priority` the first found highest priority contribution is used, duplicates with same priority raises and error, the rest are
    #     ignored.</li></ul>
    # @option options [Boolean, Integer] :flatten (false) If appended should be flattened. Also see {#flatten}.
    # @option options [Boolean] :uniq (false) If appended result should be made unique.
    #
    # @api public
    #
  def initialize(injector, binding, scope, options)
      super
      @conflict_resolution = options[:conflict_resolution].nil? ? :priority : options[:conflict_resolution]
      @uniq = !!options[:uniq]
      @flatten = options[:flatten]

      unless [:error, :merge, :append, :priority, :ignore].include?(@conflict_resolution)
        raise ArgumentError, "Unknown conflict_resolution for Multibind Hash: '#{@conflict_resolution}."
      end

      case @flatten
      when Integer
      when true
        @flatten = -1
      when false
        @flatten = nil
      when NilClass
        @flatten = nil
      else
        raise ArgumentError, "Option :flatten must be nil, Boolean, or an integer value" unless @flatten.is_a?(Integer)
      end

      if uniq || flatten || conflict_resolution.to_s == 'append'
        etype = binding.type.element_type
        unless etype.class == Types::PDataType || etype.is_a?(Types::PArrayType)
          detail = []
          detail << ":uniq" if uniq
          detail << ":flatten" if flatten
          detail << ":conflict_resolution => :append" if conflict_resolution.to_s == 'append'
          raise ArgumentError, ["Options #{detail.join(', and ')} cannot be used with a Multibind ",
            "of type #{binding.type}"].join()
        end
      end
    end

    protected

    # @api private
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
            # skip if duplicate has lower prio
            if (comparison = (seen[name] <=> entry)) <= 0
              raise ArgumentError, "Internal Error: contributions not given in decreasing precedence order" unless comparison == 0
              raise ArgumentError, "Duplicate key (same priority) contributed to Hash Multibinding '#{binding.name}', key: '#{name}'."
            end
            next

          when 'ignore'
            # skip, ignore conflict if prio is the same
            next

          when 'error'
            raise ArgumentError, "Duplicate key contributed to Hash Multibinding '#{binding.name}', key: '#{name}'."

          end
        else
          seen[name] = entry
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

    # @api private
    def merge(result, name, higher, lower)
      case conflict_resolution.to_s
      when 'append'
        unless higher.is_a?(Array)
          higher = [higher]
        end
        tmp = higher + [lower]
        tmp.flatten!(flatten) if flatten
        tmp.uniq! if uniq
        result[name] = tmp

      when 'merge'
        result[name] = lower.merge(higher)

      end
    end

    # @api private
    def assert_type(binding, tc, key, value)
      unless tc.instance?(binding.type.key_type, key)
        raise ArgumentError, ["Type Error: key contribution to #{binding.name}['#{key}'] ",
          "is incompatible with key type: #{tc.label(binding.type)}, ",
          type_error_detail(binding.type.key_type, key)].join()
      end

      if key.nil? || !key.is_a?(String) || key.empty?
        raise ArgumentError, "Entry contributing to multibind hash with id '#{binding.id}' must have a name."
      end

      unless tc.instance?(binding.type.element_type, value)
        raise ArgumentError, ["Type Error: value contribution to #{binding.name}['#{key}'] ",
          "is incompatible, ",
          type_error_detail(binding.type.element_type, value)].join()
      end
    end
  end

end
end
end
