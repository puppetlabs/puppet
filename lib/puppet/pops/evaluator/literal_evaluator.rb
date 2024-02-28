# frozen_string_literal: true

module Puppet::Pops
module Evaluator
# Literal values for
# String (not containing interpolation)
# Numbers
# Booleans
# Undef (produces nil)
# Array
# Hash
# QualifiedName
# Default (produced :default)
# Regular Expression (produces ruby regular expression)
# QualifiedReference
# AccessExpresion
#
class LiteralEvaluator
  COMMA_SEPARATOR = ', '

  def initialize
    @@literal_visitor ||= Visitor.new(self, "literal", 0, 0)
  end

  def literal(ast)
    @@literal_visitor.visit_this_0(self, ast)
  end

  def literal_Object(o)
    throw :not_literal
  end

  def literal_Factory(o)
    literal(o.model)
  end

  def literal_Program(o)
    literal(o.body)
  end

  def literal_LiteralString(o)
    o.value
  end

  def literal_QualifiedName(o)
    o.value
  end

  def literal_LiteralNumber(o)
    o.value
  end

  def literal_LiteralBoolean(o)
    o.value
  end

  def literal_LiteralUndef(o)
    nil
  end

  def literal_LiteralDefault(o)
    :default
  end

  def literal_LiteralRegularExpression(o)
    o.value
  end

  def literal_QualifiedReference(o)
    o.value
  end

  def literal_AccessExpression(o)
    # to prevent parameters with [[]] like Optional[[String]]
    throw :not_literal if o.keys.size == 1 && o.keys[0].is_a?(Model::LiteralList)
    o.keys.map { |v| literal(v) }
  end

  def literal_UnaryMinusExpression(o)
    -literal(o.expr)
  end

  def literal_ConcatenatedString(o)
    # use double quoted string value if there is no interpolation
    throw :not_literal unless o.segments.size == 1 && o.segments[0].is_a?(Model::LiteralString)
    o.segments[0].value
  end

  def literal_LiteralList(o)
    o.values.map { |v| literal(v) }
  end

  def literal_LiteralHash(o)
    o.entries.each_with_object({}) do |entry, result|
      result[literal(entry.key)] = literal(entry.value)
    end
  end
end
end
end
