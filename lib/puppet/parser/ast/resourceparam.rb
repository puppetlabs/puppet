# The AST object for the parameters inside resource expressions
#
class Puppet::Parser::AST::ResourceParam < Puppet::Parser::AST::Branch
  attr_accessor :value, :param, :add

  def each
    [@param, @value].each { |child| yield child }
  end

  # Return the parameter and the value.
  def evaluate(scope)
    value = @value.safeevaluate(scope)
    return Puppet::Parser::Resource::Param.new(
      :name   => @param,
      :value  => value.nil? ? :undef : value,
      :source => scope.source, 
      :line   => self.line,
      :file   => self.file,
      :add    => self.add
    )
  end

  def to_s
    "#{@param} => #{@value.to_s}"
  end
end
