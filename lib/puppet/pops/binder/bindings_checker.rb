# A validator/checker of a bindings model
#
class Puppet::Pops::Binder::BindingsChecker
  Bindings = Puppet::Pops::Binder::Bindings
  Issues = Puppet::Pops::Binder::BinderIssues
  Types = Puppet::Pops::Types

  attr_reader :type_calculator
  attr_reader :acceptor

  def initialize(diagnostics_producer)
    @@check_visitor    ||= Puppet::Pops::Visitor.new(nil, "check", 0, 0)
    @@producer_visitor ||= Puppet::Pops::Visitor.new(nil, "producer", 1, 1)
    @type_calculator  = Puppet::Pops::Types::TypeCalculator.new()
    @acceptor         = diagnostics_producer
  end

  # Performs producer validity check
  def producer(p, b)
    @@producer_visitor.visit_this(self, p, b)
  end

  # Performs binding validity check
  def check(b)
    @@check_visitor.visit_this(self, b)
  end

  # Checks that a binding has a producer and a type
  def check_Binding(b)
    # Must have a type
    acceptor.accept(Issues::MISSING_TYPE, b) unless b.type.is_a?(Types::PObjectType)

    # Must have a producer
    if b.producer.is_a?(Bindings::ProducerDescriptor)
      producer(b.producer, b)
    else
      acceptor.accept(Issues::MISSING_PRODUCER, b)
    end
  end

  # Checks that the producer is a Multibind producer and that the type is a PCollectionType
  def check_Multibinding(b)
    # id is optional (empty id blocks contributions)

    # A multibinding must have PCollectionType
    acceptor.accept(Issues::MULTIBIND_TYPE_ERROR, b, {:actual_type => b.type})  unless b.type.is_a?(Types::PCollectionType)

    if b.producer != nil # if it's nil, a suitable producer will be picked automatically
      if b.producer.is_a?(Bindings::MultibindProducerDescriptor)
        producer(b.producer, b)
      elsif b.producer != nil
        acceptor.accept(Issues::MULTIBIND_NOT_COLLECTION_PRODUCER, b, {:actual_producer => b.producer})
      end
    end
  end

  # Checks that the bindings object contains at least one binding. Then checks each binding in turn
  def check_Bindings(b)
    if b.bindings == nil || b.bindings.empty?
      acceptor.accept(Issues::MISSING_BINDINGS, b)
    else
      b.bindings.each { |c| check(c) }
    end
  end

  # Checks that a name has been associated with the bindings
  def check_NamedBindings(b)
    acceptor.accept(Issues::MISSING_BINDINGS_NAME, b) unless has_chars?(b.name)
    check_Bindings(b)
  end

  # Check that the binding contains at least one predicate and that all predicates are categorized and has a value
  def check_CategorizedBindings(b)
    if(b.predicates == nil || b.predicates.empty?)
      acceptor.accept(Issues::MISSING_PREDICATES, b)
    else
      acceptor.accept(Issues::MISSING_CATEGORIZATION, b) unless b.predicates.index { |p| !has_chars?(p.categorization) } == nil
      acceptor.accept(Issues::MISSING_CATEGORY_VALUE, b) unless b.predicates.index { |p| !has_chars?(p.value) } == nil
    end
    check_Bindings(b)
  end

  # Checks that the binding has layers and that each layer has a name and at least one binding
  def check_LayeredBindings(b)
    if(b.layers == nil || b.layers.empty?)
      acceptor.accept(Issues::MISSING_LAYERS, b)
    else
      acceptor.accept(Issues::MISSING_LAYER_NAME, b) unless b.layers.index { |layer| !has_chars?(layer.name) } == nil
      b.layers.each do |layer|
        if layer.bindings == nil || layer.bindings.empty?
          acceptor.accept(Issues::MISSING_BINDINGS_IN_LAYER, b, { :layer => layer })
        else
          layer.bindings.each do | lb |
            check(lb)
          end
        end
      end
    end
  end

  # Checks that the non caching producer has a producer to delegate to
  def producer_NonCachingProducerDescriptor(p, b)
    if p.producer.is_a?(Bindings::ProducerDescriptor)
      producer(o.producer, b)
    else
      acceptor.accept(Issues::PRODUCER_MISSING_PRODUCER, p, {:binding => b})
    end
  end

  # Checks that a constant value has been declared in the producer and that the type
  # of the value is compatible with the type declared in the binding
  def producer_ConstantProducerDescriptor(p, b)
    # the product must be of compatible type
    # TODO: Likely to change when value becomes a typed Puppet Object
    if p.value == nil
      acceptor.accept(Issues::MISSING_VALUE, p, {:binding => b} )
    else
      infered = type_calculator.infer(p.value)
      acceptor.accept(Issues::INCOMPATIBLE_TYPE, p, {:binding => b, :expected_type => b.type, :actual_type => infered}) unless type_calculator.assignable?(b.type, infered)
    end
  end

  # Checks that an expression has been declared in the producer
  def producer_EvaluatingProducerDescriptor(p, b)
    acceptor.accept(Issues::MISSING_EXPRESSION, p, {:binding => b}) unless p.expression.is_a?(Puppet::Pops::Model::Expression)
  end

  # Checks that a class name has been declared in the producer
  def producer_InstanceProducerDescriptor(p, b)
    acceptor.accept(Issues::MISSING_CLASS_NAME, p, {:binding => b}) unless has_chars?(p.class_name)
  end

  # Checks that a type and a name has been declared. The type must be assignable to the type
  # declared in the binding. The name can be an empty string to denote 'no name'
  def producer_LookupProducerDescriptor(p, b)
    acceptor.accept(Issues::INCOMPATIBLE_TYPE, p, {:binding => b, :expected_type => b.type, :actual_type => p.type }) unless type_calculator.assignable(b.type)
    acceptor.accept(Issues::MISSING_NAME, p, {:binding => b}) if p.name == nil # empty string is OK
  end

  # Checks that a detail_name has been declared, then calls producer_LookupProducerDescriptor to perform
  # checks associated with the super class
  def producer_MultiLookupProducerDescriptor(p, b)
    acceptor.accept(Issues::MISSING_NAME, p, {:binding => b}) unless has_chars?(p.detail_name)
    producer_LookupProducerDescriptor(p, b)
  end

  # Checks that the type declared in the binder is a PArrayType
  def producer_ArrayMultibindProducerDescriptor(p, b)
    acceptor.accept(Issues::MULTIBIND_INCOMPATIBLE_TYPE, p, {:binding => b, :actual_type => b.type}) unless b.type.is_a?(Types::PArrayType)
  end

  # Checks that the type declared in the binder is a PHashType
  def producer_HashMultibindProducerDescriptor(p, b)
    acceptor.accept(Issues::MULTIBIND_INCOMPATIBLE_TYPE, p, {:binding => b, :actual_type => b.type}) unless b.type.is_a?(Types::PHashType)
  end

  # Checks that the producer that this producer delegates to is declared
  def producer_ProducerProducerDescriptor(p, b)
    if p.producer.is_a?(Bindings::ProducerDescriptor)
      producer(o.producer, b)
    else
      acceptor.accept(Issues::PRODUCER_MISSING_PRODUCER, p, {:binding => b})
    end
  end

  # Returns true if the argument is a non empty string
  def has_chars?(s)
    s.is_a?(String) && !s.empty?
  end
end
