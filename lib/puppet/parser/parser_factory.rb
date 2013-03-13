
module Puppet; module Parser
  
  # The ParserFactory makes selection of parser possible.
  # Currently, it is possible to switch between two different parsers:
  # * classic_parser, the parser in 3.1
  # * eparser, the Expression Based Parser
  #
  class ParserFactory
    # Produces a parser instance for the given environment
    def self.parser(environment)
      eparser(environment)
    end
    
    # Creates an instance of the classic parser.
    #
    def self.classic_parser(environment)
      require 'puppet/parser'
      Puppet::Parser::Parser.new(environment)    
    end
    
    # Creates an instance of the expression based parser 'eparser'
    #
    def self.eparser(environment)
      require 'puppet/parser'
      require 'puppet/parser/eparser_adapter'
      EParserAdapter.new(Puppet::Parser::Parser.new(environment))
    end
  end
  
end; end