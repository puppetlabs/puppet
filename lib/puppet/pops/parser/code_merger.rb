
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
    children = parse_results.select {|x| !x.nil? && x.code}.flat_map do |parsed_class|
      flatten(parsed_class)
    end
    Puppet::Parser::AST::BlockExpression.new(:children => children)
  end

  # Append new parse results on the +right+ with existing results on the +left+.
  # @return Puppet::Parser::AST::BlockExpression
  def append(left, right)
    # if the left hasn't been flattened yet, then fall back to concatenate
    can_append = left &&
                 left.code.instance_of?(Puppet::Parser::AST::BlockExpression) &&
                 !left.code.children.any? { |c| c.instance_of?(Puppet::Pops::Model::Factory) }

    if can_append
      child = flatten(right)
      if child.instance_of?(Array)
        left.code.children.concat(child)
      else
        left.code.children << child
      end
    else
      left.code = concatenate([left, right])
      left
    end
  end

  private

  def flatten(parsed_class)
    case parsed_class.code
    when Puppet::Parser::AST::BlockExpression
      # the BlockExpression wraps a single 4x instruction that is most likely wrapped in a Factory
      parsed_class.code.children.map {|c| c.is_a?(Puppet::Pops::Model::Factory) ? c.model : c }
    when Puppet::Pops::Model::Factory
      # If it is a 4x instruction wrapped in a Factory
      parsed_class.code.model
    else
      # It is the instruction directly
      parsed_class.code
    end
  end
end
