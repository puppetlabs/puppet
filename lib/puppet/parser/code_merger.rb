
class Puppet::Parser::CodeMerger

  # Concatenates the logic in the array of parse results into one parse result
  # @return Puppet::Parser::AST::BlockExpression
  #
  def concatenate(parse_results)
    children = parse_results.select {|x| !x.nil? && x.code}.reduce([]) do |memo, parsed_class|
      memo + parsed_class.code.children
    end
    Puppet::Parser::AST::BlockExpression.new(:children => children)
  end
end
