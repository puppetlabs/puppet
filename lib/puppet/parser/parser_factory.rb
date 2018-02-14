module Puppet; end

module Puppet::Parser
  # The ParserFactory makes selection of parser possible.
  # Currently, it is possible to switch between two different parsers:
  # * classic_parser, the parser in 3.1
  # * eparser, the Expression Based Parser
  #
  class ParserFactory
    # Produces a parser instance for the given environment
    def self.parser
      evaluating_parser
    end

    # Creates an instance of an E4ParserAdapter that adapts an
    # EvaluatingParser to the 3x way of parsing.
    #
    def self.evaluating_parser
      unless defined?(Puppet::Parser::E4ParserAdapter)
        require 'puppet/parser/e4_parser_adapter'
        require 'puppet/pops/parser/code_merger'
      end
      E4ParserAdapter.new
    end

    def self.code_merger
      Puppet::Pops::Parser::CodeMerger.new
    end
  end
end
