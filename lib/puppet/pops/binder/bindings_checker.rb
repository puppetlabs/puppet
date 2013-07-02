# A validator/checker of a bindings model
#
class Puppet::Pops::Binder::BindingsChecker
  Bindings = Puppet::Pops::Binder::Bindings
  Issues = Puppet::Pops::Binder::BinderIssues
  Types = Puppet::Pops::Types

  attr_reader :type_calculator
  attr_reader :acceptor

  def initialize(diagnostics_producer)
    @@check_visitor   ||= Puppet::Pops::Visitor.new(nil, "check", 0, 0)
    @type_calculator  = Puppet::Pops::Types::TypeCalculator.new()
    @acceptor         = diagnostics_producer
  end

  # Validates the entire model by visiting each model element and calling `check`.
  # The result is collected (or acted on immediately) by the configured diagnostic provider/acceptor
  # given when creating this Checker.
  #
  def validate(b)
    check(b)
    b.eAllContents.each {|c| check(c) }
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
    acceptor.accept(Issues::MISSING_PRODUCER, b) unless b.producer.is_a?(Bindings::ProducerDescriptor)
  end

  # Checks that the producer is a Multibind producer and that the type is a PCollectionType
  def check_Multibinding(b)
    # id is optional (empty id blocks contributions)

    # A multibinding must have PCollectionType
    acceptor.accept(Issues::MULTIBIND_TYPE_ERROR, b, {:actual_type => b.type})  unless b.type.is_a?(Types::PCollectionType)

    # if the producer is nil, a suitable producer will be picked automatically
    unless b.producer.nil? || b.producer.is_a?(Bindings::MultibindProducerDescriptor)
      acceptor.accept(Issues::MULTIBIND_NOT_COLLECTION_PRODUCER, b, {:actual_producer => b.producer})
    end
  end

  # Checks that the bindings object contains at least one binding. Then checks each binding in turn
  def check_Bindings(b)
    acceptor.accept(Issues::MISSING_BINDINGS, b) unless has_entries?(b.bindings)
  end

  # Checks that a name has been associated with the bindings
  def check_NamedBindings(b)
    acceptor.accept(Issues::MISSING_BINDINGS_NAME, b) unless has_chars?(b.name)
    check_Bindings(b)
  end

  # Check that the category has a categorization and a value
  def check_Category(c)
    acceptor.accept(Issues::MISSING_CATEGORIZATION, binding_parent(c)) unless has_chars?(c.categorization)
    acceptor.accept(Issues::MISSING_CATEGORY_VALUE, binding_parent(c)) unless has_chars?(c.value)
  end

  # Check that the binding contains at least one predicate and that all predicates are categorized and has a value
  def check_CategorizedBindings(b)
    acceptor.accept(Issues::MISSING_PREDICATES, b) unless has_entries?(b.predicates)
    check_Bindings(b)
  end

  # Check that the layer has at least one binding
  def check_NamedLayer(l)
    acceptor.accept(Issues::MISSING_LAYER_NAME, binding_parent(l)) unless has_chars?(l.name)
    acceptor.accept(Issues::MISSING_BINDINGS_IN_LAYER, binding_parent(l), { :layer => l.name }) unless has_entries?(l.bindings)
  end

  # Checks that the binding has layers and that each layer has a name and at least one binding
  def check_LayeredBindings(b)
    acceptor.accept(Issues::MISSING_LAYERS, b) unless has_entries?(b.layers)
  end

  # Checks that the non caching producer has a producer to delegate to
  def check_NonCachingProducerDescriptor(p)
    acceptor.accept(Issues::PRODUCER_MISSING_PRODUCER, p) unless p.producer.is_a?(Bindings::ProducerDescriptor)
  end

  # Checks that a constant value has been declared in the producer and that the type
  # of the value is compatible with the type declared in the binding
  def check_ConstantProducerDescriptor(p)
    # the product must be of compatible type
    # TODO: Likely to change when value becomes a typed Puppet Object
    b = binding_parent(p)
    if p.value.nil?
      acceptor.accept(Issues::MISSING_VALUE, p, {:binding => b})
    else
      infered = type_calculator.infer(p.value)
      unless type_calculator.assignable?(b.type, infered)
        acceptor.accept(Issues::INCOMPATIBLE_TYPE, p, {:binding => b, :expected_type => b.type, :actual_type => infered})
      end
    end
  end

  # Checks that an expression has been declared in the producer
  def check_EvaluatingProducerDescriptor(p)
    unless p.expression.is_a?(Puppet::Pops::Model::Expression)
      acceptor.accept(Issues::MISSING_EXPRESSION, p, {:binding => binding_parent(p)})
    end
  end

  # Checks that a class name has been declared in the producer
  def check_InstanceProducerDescriptor(p)
    acceptor.accept(Issues::MISSING_CLASS_NAME, p, {:binding => binding_parent(p)}) unless has_chars?(p.class_name)
  end

  # Checks that a type and a name has been declared. The type must be assignable to the type
  # declared in the binding. The name can be an empty string to denote 'no name'
  def check_LookupProducerDescriptor(p)
    b = binding_parent(p)
    unless type_calculator.assignable(b.type, p.type)
      acceptor.accept(Issues::INCOMPATIBLE_TYPE, p, {:binding => b, :expected_type => b.type, :actual_type => p.type })
    end
    acceptor.accept(Issues::MISSING_NAME, p, {:binding => b}) if p.name.nil? # empty string is OK
  end

  # Checks that a detail_name has been declared, then calls producer_LookupProducerDescriptor to perform
  # checks associated with the super class
  def check_MultiLookupProducerDescriptor(p)
    acceptor.accept(Issues::MISSING_NAME, p, {:binding => binding_parent(p)}) unless has_chars?(p.detail_name)
    check_LookupProducerDescriptor(p)
  end

  # Checks that the type declared in the binder is a PArrayType
  def check_ArrayMultibindProducerDescriptor(p)
    b = binding_parent(p)
    acceptor.accept(Issues::MULTIBIND_INCOMPATIBLE_TYPE, p, {:binding => b, :actual_type => b.type}) unless b.type.is_a?(Types::PArrayType)
  end

  # Checks that the type declared in the binder is a PHashType
  def check_HashMultibindProducerDescriptor(p)
    b = binding_parent(p)
    acceptor.accept(Issues::MULTIBIND_INCOMPATIBLE_TYPE, p, {:binding => b, :actual_type => b.type}) unless b.type.is_a?(Types::PHashType)
  end

  # Checks that the producer that this producer delegates to is declared
  def check_ProducerProducerDescriptor(p)
    unless p.producer.is_a?(Bindings::ProducerDescriptor)
      acceptor.accept(Issues::PRODUCER_MISSING_PRODUCER, p, {:binding => binding_parent(p)})
    end
  end

  def check_PObjectType(t)
    # Do nothing
  end

  # Returns true if the argument is a non empty string
  def has_chars?(s)
    s.is_a?(String) && !s.empty?
  end

  def has_entries?(s)
    !(s.nil? || s.empty?)
  end

  def binding_parent(p)
    begin
      x = p.eContainer
      if x.nil?
        acceptor.accept(Issues::MODEL_OBJECT_IS_UNBOUND, p)
        return nil
      end
      p = x
    end while !p.is_a?(Bindings::AbstractBinding)
    p
  end
end
