# Evaluates contained expressions, produce result of the last
#
class Puppet::Parser::AST::BlockExpression < Puppet::Parser::AST::Branch
  def evaluate(scope)
    @children.reduce(nil) { |_, child| child.safeevaluate(scope) }
  end

  def sequence_with(other)
    Puppet::Parser::AST::BlockExpression.new(:children => self.children + other.children)
  end

  def to_s
    "[" + @children.collect { |c| c.to_s }.join(', ') + "]"
  end
end
