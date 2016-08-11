require 'rgen/ecore/ecore'

# Literal values for
#
#   * String
#   * Numbers
#   * Booleans
#   * Undef (produces nil)
#   * Array
#   * Hash where keys must be Strings
#   * QualifiedName
#
# Not considered literal:
#
#   * QualifiedReference  # i.e. File, FooBar
#   * Default is not accepted as being literal
#   * Regular Expression is not accepted as being literal
#   * Hash with non String keys
#   * String with interpolatin
#
class Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator
  #include Puppet::Pops::Utils

  COMMA_SEPARATOR = ', '.freeze

  def initialize
    @@literal_visitor ||= Puppet::Pops::Visitor.new(self, "literal", 0, 0)
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

  def literal_ConcatenatedString(o)
    # use double quoted string value if there is no interpolation
    throw :not_literal unless o.segments.size == 1 && o.segments[0].is_a?(Puppet::Pops::Model::LiteralString)
    o.segments[0].value
  end

  def literal_LiteralList(o)
    o.values.map {|v| literal(v) }
  end

  def literal_LiteralHash(o)
    o.entries.reduce({}) do |result, entry|
      key = literal(entry.key)
      throw :not_literal unless key.is_a?(String)
      result[key] = literal(entry.value)
      result
    end
  end
end
