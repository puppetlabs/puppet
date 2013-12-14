
class Puppet::Parser::CodeMerger

  # Concatenates the logic in the array of parse results into one parse result
  def concatenate(parse_results)
    children = parse_results.select {|x| !x.nil? && x.code}.reduce([]) do |memo, parsed_class|
      memo + parsed_class.code.children
    end
    main = Puppet::Parser::AST::BlockExpression.new(:children => children)
    Puppet::Parser::AST::Hostclass.new('', :code => main)
  end
end