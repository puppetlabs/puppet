# The RelationshipOperator implements the semantics of the -> <- ~> <~ operators creating relationships or notification
# relationships between the left and right hand side's references to resources.
#
# This is separate class since a second level of evaluation is required that transforms string in left or right hand
# to type references. The task of "making a relationship" is delegated to the "runtime support" class that is included.
# This is done to separate the concerns of the new evaluator from the 3x runtime; messy logic goes into the runtime support
# module. Later when more is cleaned up this can be simplified further.
#
class Puppet::Pops::Evaluator::RelationshipOperator

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Puppet::Pops::Evaluator::Runtime3Support

  def initialize
    @type_transformer_visitor = Puppet::Pops::Visitor.new(self, "transform", 1, 1)
    @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
    @type_parser = Puppet::Pops::Types::TypeParser.new()

    @catalog_type = Puppet::Pops::Types::TypeFactory.catalog_entry()
  end

  def transform(o, scope)
    @type_transformer_vistor.visit(o, scope)
  end

  # Catch all non transformable objects
  # @api private
  def transform_Object(o, scope)
    fail("Not a valid reference in a relationship", o, scope)
  end

  # A string must be a type reference in string format
  # @api private
  def transform_String(o, scope)
    assert_catalog_type(@type_parser.parse(o.value))
  end

  # A qualified name is short hand for a class with this name
  # @api private
  def transform_QualifiedName(o, scope)
    Puppet::Pops::Types::TypeFactory.host_class(o.value)
  end

  # Types are what they are, just check the type
  # @api private
  def transform_PAbstractType(o, scope)
    assert_catalog_type(o, scope)
  end

  # Asserts (and returns) the type if it is a PCatalogEntryType
  # (A PCatalogEntryType is the base class of PHostClassType, and PResourceType).
  #
  def assert_catalog_type(o, scope)
    unless @type_calculator.assignable?(@catalog_type, o)
      fail("The reference is not a catalog type", o, scope)
    end
    # TODO must check if this is an abstract PResourceType (i.e. without a type_name) - which should fail
    o
  end

  RELATIONSHIP_OPERATORS = [:'->', :'~>', :'<-', :'<~']
  REVERSE_OPERATORS      = [:'<-', :'<~']
  RELATION_TYPE = {
    :'->' => :relationship,
    :'<-' => :relationship,
    :'~>' => :subscription,
    :'<~' => :subscription
  }

  def evaluate (left_right_evaluated, relationship_expression, scope)
    # assert operator (should have been validated, but this logic makes assumptions which would
    # screw things up royally). Better safe than sorry.
    unless RELATIONSHIP_OPERATORS.include?(relationship_expression.operator)
      fail("Unknown relationship operator #{relationship_expression.operator}.", relationship_expression, scope)
    end

    # Turn each side into an array of types (this also asserts their type)
    # (note wrap in array first if value is not already an array)
    #
    # TODO: Later when objects are Puppet Runtime Objects and know their type, it will be more efficient to check/infer
    # the type first since a chained operation then does not have to visit each element again. This is not meaningful now
    # since inference needs to visit each object each time, and this is what the transformation does anyway).
    #
    # real is [left, right], and both the left and right may be a single value or an array. In each case all content
    # should be flattened, and then transformed to a type.
    #
    real = real.collect {|x| [x].flatten.collect {|x| transform(x, scope) }}

    # reverse order if operator is Right to Left
    source, target = reverse_operator?(relationship_expression) ? real.reverse : real

    # Add the relationships to the catalog
    source.each {|s| target.each {|t| add_relationship(s, t, RELATION_TYPE[relationship_expression.operator]) }}

    # Produce the transformed source RHS (if this is a chain, this does not need to be done again)
    real.slice(1)
  end

  def reverse_operator?(o)
    REVERSE_OPERATORS.include?(o.operator)
  end
end
