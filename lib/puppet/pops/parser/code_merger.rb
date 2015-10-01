
class Puppet::Pops::Parser::CodeMerger

  # Concatenates the logic in the array of parse results into one parse result.
  # @return Puppet::Parser::AST::BlockExpression
  #
  def concatenate(parse_results)
    # this is a bit brute force as the result is already 3x ast with wrapped 4x content
    # this could be combined in a more elegant way, but it is only used to process a handful of files
    # at the beginning of a puppet run. TODO: Revisit for Puppet 4x when there is no 3x ast at the top.
    # PUP-5299, some sites have thousands of entries, and run out of stack when evaluating - the logic
    # below maps the logic as flatly as possible.
    #
    children = parse_results.select {|x| !x.nil? && x.code}.reduce([]) do |memo, parsed_class|
      case parsed_class.code
      when Puppet::Parser::AST::BlockExpression
        # the BlockExpression wraps a single 4x instruction that is most likely wrapped in a Factory
        memo += parsed_class.code.children.map {|c| c.is_a?(Puppet::Pops::Model::Factory) ? c.model : c }
      when Puppet::Pops::Model::Factory
        # If it is a 4x instruction wrapped in a Factory
        memo += parsed_class.code.model
      else
        # It is the instruction directly
        memo << parsed_class.code
      end
    end
    Puppet::Parser::AST::BlockExpression.new(:children => children)
  end
end
