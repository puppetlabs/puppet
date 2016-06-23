module Puppet::Pops
module Evaluator
# The RelationshipOperator implements the semantics of the -> <- ~> <~ operators creating relationships or notification
# relationships between the left and right hand side's references to resources.
#
# This is separate class since a second level of evaluation is required that transforms string in left or right hand
# to type references. The task of "making a relationship" is delegated to the "runtime support" class that is included.
# This is done to separate the concerns of the new evaluator from the 3x runtime; messy logic goes into the runtime support
# module. Later when more is cleaned up this can be simplified further.
#
class RelationshipOperator

  # Provides access to the Puppet 3.x runtime (scope, etc.)
  # This separation has been made to make it easier to later migrate the evaluator to an improved runtime.
  #
  include Runtime3Support

  class IllegalRelationshipOperandError < RuntimeError
    attr_reader :operand
    def initialize operand
      @operand = operand
    end
  end

  class NotCatalogTypeError < RuntimeError
    attr_reader :type
    def initialize type
      @type = type
    end
  end

  def initialize
    @type_transformer_visitor = Visitor.new(self, "transform", 1, 1)
    @type_calculator = Types::TypeCalculator.new()

    tf = Types::TypeFactory
    @catalog_type = tf.variant(tf.catalog_entry, tf.type_type(tf.catalog_entry))
  end

  def transform(o, scope)
    @type_transformer_visitor.visit_this_1(self, o, scope)
  end

  # Catch all non transformable objects
  # @api private
  def transform_Object(o, scope)
    raise IllegalRelationshipOperandError.new(o)
  end

  # A Resource is by definition a Catalog type, but of 3.x type
  # @api private
  def transform_Resource(o, scope)
    Types::TypeFactory.resource(o.type, o.title)
  end

  # A string must be a type reference in string format
  # @api private
  def transform_String(o, scope)
    assert_catalog_type(Types::TypeParser.singleton.parse(o, scope), scope)
  end

  # A qualified name is short hand for a class with this name
  # @api private
  def transform_QualifiedName(o, scope)
    Types::TypeFactory.host_class(o.value)
  end

  # Types are what they are, just check the type
  # @api private
  def transform_PAnyType(o, scope)
    assert_catalog_type(o, scope)
  end

  # This transforms a 3x Collector (the result of evaluating a 3x AST::Collection).
  # It is passed through verbatim since it is evaluated late by the compiler. At the point
  # where the relationship is evaluated, it is simply recorded with the compiler for later evaluation.
  # If one of the sides of the relationship is a Collector it is evaluated before the actual
  # relationship is formed. (All of this happens at a later point in time.
  #
  def transform_Collector(o, scope)
    o
  end

  def transform_AbstractCollector(o, scope)
    o
  end

  # Array content needs to be transformed
  def transform_Array(o, scope)
    o.map{|x| transform(x, scope) }
  end

  # Asserts (and returns) the type if it is a PCatalogEntryType
  # (A PCatalogEntryType is the base class of PHostClassType, and PResourceType).
  #
  def assert_catalog_type(o, scope)
    unless @type_calculator.assignable?(@catalog_type, o)
      raise NotCatalogTypeError.new(o)
    end
    # TODO must check if this is an abstract PResourceType (i.e. without a type_name) - which should fail ?
    # e.g. File -> File (and other similar constructs) - maybe the catalog protects against this since references
    # may be to future objects...
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

  # Evaluate a relationship.
  # TODO: The error reporting is not fine grained since evaluation has already taken place
  # There is no references to the original source expressions at this point, only the overall
  # relationship expression. (e.g.. the expression may be ['string', func_call(), etc.] -> func_call())
  # To implement this, the general evaluator needs to be able to track each evaluation result and associate
  # it with a corresponding expression. This structure should then be passed to the relationship operator.
  #
  def evaluate (left_right_evaluated, relationship_expression, scope)
    # assert operator (should have been validated, but this logic makes assumptions which would
    # screw things up royally). Better safe than sorry.
    unless RELATIONSHIP_OPERATORS.include?(relationship_expression.operator)
      fail(Issues::UNSUPPORTED_OPERATOR, relationship_expression, {:operator => relationship_expression.operator})
    end

    begin
      # Turn each side into an array of types (this also asserts their type)
      # (note wrap in array first if value is not already an array)
      #
      # TODO: Later when objects are Puppet Runtime Objects and know their type, it will be more efficient to check/infer
      # the type first since a chained operation then does not have to visit each element again. This is not meaningful now
      # since inference needs to visit each object each time, and this is what the transformation does anyway).
      #
      # real is [left, right], and both the left and right may be a single value or an array. In each case all content
      # should be flattened, and then transformed to a type. left or right may also be a value that is transformed
      # into an array, and thus the resulting left and right must be flattened individually
      # Once flattened, the operands should be sets (to remove duplicate entries)
      #
      real = left_right_evaluated.collect {|x| [x].flatten.collect {|y| transform(y, scope) }}
      real[0].flatten!
      real[1].flatten!
      real[0].uniq!
      real[1].uniq!

      # reverse order if operator is Right to Left
      source, target = reverse_operator?(relationship_expression) ? real.reverse : real

      # Add the relationships to the catalog
      source.each {|s| target.each {|t| add_relationship(s, t, RELATION_TYPE[relationship_expression.operator], scope) }}

      # Produce the transformed source RHS (if this is a chain, this does not need to be done again)
      real.slice(1)
    rescue NotCatalogTypeError => e
      fail(Issues::NOT_CATALOG_TYPE, relationship_expression, {:type => @type_calculator.string(e.type)})
    rescue IllegalRelationshipOperandError => e
      fail(Issues::ILLEGAL_RELATIONSHIP_OPERAND_TYPE, relationship_expression, {:operand => e.operand})
    end
  end

  def reverse_operator?(o)
    REVERSE_OPERATORS.include?(o.operator)
  end
end
end
end
