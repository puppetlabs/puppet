require 'puppet/parser/e_parser_adapter'

module Puppet; module Parser; end; end

# The EppParserAdapter adapts an instance of the EppParser to the 3.x puppet runtime environment.
# The EppParserAdapter is a validating parser for EPP (Embedded Puppet templates).
#
class Puppet::Parser::EppParserAdapter < Puppet::Parser::EParserAdapter

  # Creates the parser to use
  def create_parser()
    Puppet::Pops::Parser::EppParser.new()
  end

  # Wraps the result of parsing. For Epp the result does not have to be wrapped.
  def wrap_result(parse_result)
    parse_result
  end

  # This implementation always returns false since it should be possible to parse a template.rb (that produces
  # ruby code). An Epp Parser never parses Ruby.
  def parse_ruby?(f)
    false
  end

end