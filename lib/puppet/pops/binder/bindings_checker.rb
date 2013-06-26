# A validator/checker of a bindings model
#
class Puppet::Pops::Binder::BindingsChecker
  Bindings = Puppet::Pops::Binder::Bindings
  Issues = Puppet::Pops::Binder::BinderIssues
  Types = Puppet::Pops::Types

  attr_reader :type_calculator
  def intialize
    @@check_visitor  ||= Puppet::Pops::Visitor.new(nil, "check", 0, 0)
    @type_calculator   = Puppet::Pops::Types::TypeCalculator.new()
    @type_factory      = Puppet::Pops::Types::TypeFactory.new()
  end

  def check_Binding(o)
    # Must have a type
    acceptor.accept(Issues::MISSING_TYPE, o) unless o.type.is_a?(Types::PObjectType)

    # Must have a producer
    acceptor.accept(Issues::MISSING_PRODUCER, o) unless o.producer.is_a?(Bindings::Producer)

    # if it is a literal or instance producer, the product must be of compatible type
    case o.producer
    when Bindings::LiteralProducer
      infered = type_calculator.infer(o.producer.value)
      unless type_calculator.assignable?(o.type, infered)
        acceptor.accept(Issues::INCOMPATIBLE_TYPE, o, {:expected_type => o.type, :actual_type => infered})
      end
    when Bindings::InstanceProducer
    end
    if o.producer.is_a?(Bindings::LiteralProducer)
    end
  end

  def check_Multibinding(o)
    # A multibind must have an Array or a Hash type as its type
    unless type_calculator.assignable?(type_factory.collection(), o.type)
      acceptor.accept(Issues::MULTIBIND_TYPE_ERROR, o, {:actual_type => o.type})
    end

    # id is optional (empty id blocks contributions)

    # must have a producer that matches the multibind-type
    case o.type
    when Puppet::Pops::Types::PArrayType
      unless o.producer.is_a?(Puppet::Pops::Binder::Bindings::ArrayMultibindProducer)
        acceptor.accept(Issues::MULTIBIND_NOT_ARRAY_PRODUCER, o, {:actual_producer => o.producer})
      end
    when Puppet::Pops::Types::PHashType
      unless o.producer.is_a?(Puppet::Pops::Binder::Bindings::HashMultibindProducer)
        acceptor.accept(Issues::MULTIBIND_NOT_HASH_PRODUCER, o, {:actual_producer => o.producer})
      end
    end
  end
end