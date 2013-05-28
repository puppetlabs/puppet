module Puppet; end

module Puppet::Parser
  # The ParserFactory makes selection of parser possible.
  # Currently, it is possible to switch between two different parsers:
  # * classic_parser, the parser in 3.1
  # * eparser, the Expression Based Parser
  #
  class ParserFactory
    # Produces a parser instance for the given environment
    def self.parser(environment)
      case Puppet[:parser]
      when 'future'
        eparser(environment)
      else
        classic_parser(environment)
      end
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
      # Since RGen is optional, test that it is installed
      @@asserted ||= false
      assert_rgen_installed() unless @asserted
      require 'puppet/parser'
      require 'puppet/parser/e_parser_adapter'
      EParserAdapter.new(Puppet::Parser::Parser.new(environment))
    end

    private

    def self.assert_rgen_installed
      begin
        require 'rgen/metamodel_builder'
      rescue LoadError
        raise Puppet::DevError.new("The gem 'rgen' version >= 0.6.1 is required when using the setting '--parser future'. Please install 'rgen'.")
      end
      # Since RGen is optional, there is nothing specifying its version.
      # It is not installed in any controlled way, so not possible to use gems to check (it may be installed some other way).
      # Instead check that "eContainer, and eContainingFeature" has been installed.
      require 'puppet/pops'
      begin
        litstring = Puppet::Pops::Model::LiteralString.new();
        container = Puppet::Pops::Model::ArithmeticExpression.new();
        container.left_expr = litstring
        raise "no eContainer" if litstring.eContainer() != container
        raise "no eContainingFeature" if litstring.eContainingFeature() != :left_expr
      rescue
        raise Puppet::DevError.new("The gem 'rgen' version >= 0.6.1 is required when using '--parser future'. An older version is installed, please update.")
      end
    end
  end

end
