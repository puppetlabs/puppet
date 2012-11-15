require 'puppet/parser/ast'
require 'puppet/parser/ast/branch'
require 'puppet/parser/relationship'

class Puppet::Parser::AST::Relationship < Puppet::Parser::AST::Branch
  RELATIONSHIP_TYPES = %w{-> <- ~> <~}

  attr_accessor :left, :right, :arrow, :type

  # Evaluate our object, but just return a simple array of the type
  # and name.
  def evaluate(scope)
    real_left = left.safeevaluate(scope)
    real_right = right.safeevaluate(scope)

    source, target = sides2edge(real_left, real_right)
    scope.compiler.add_relationship Puppet::Parser::Relationship.new(source, target, type)

    real_right
  end

  def initialize(left, right, arrow, args = {})
    super(args)
    unless RELATIONSHIP_TYPES.include?(arrow)
      raise ArgumentError, "Invalid relationship type #{arrow.inspect}; valid types are #{RELATIONSHIP_TYPES.collect { |r| r.to_s }.join(", ")}"
    end
    @left, @right, @arrow = left, right, arrow
  end

  def type
    subscription? ? :subscription : :relationship
  end

  def sides2edge(left, right)
    out_edge? ? [left, right] : [right, left]
  end

  private

  def out_edge?
    ["->", "~>"].include?(arrow)
  end

  def subscription?
    ["~>", "<~"].include?(arrow)
  end
end
