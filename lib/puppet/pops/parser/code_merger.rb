
class Puppet::Pops::Parser::CodeMerger

  # Concatenates the logic in the array of parse results into one parse result.
  # @return Puppet::Parser::AST::BlockExpression
  #
  def concatenate(parse_results)
    # this is a bit brute force as the result is already 3x ast with wrapped 4x content
    # this could be combined in a more elegant way, but it is only used to process a handful of files
    # at the beginning of a puppet run. TODO: Revisit for Puppet 4x when there is no 3x ast at the top.
    #
    children = parse_results.select {|x| !x.nil? && x.code}.reduce([]) do |memo, parsed_class|
      memo << parsed_class.code
    end
    Puppet::Parser::AST::BlockExpression.new(:children => children)
  end
end
