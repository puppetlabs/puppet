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
        if Puppet[:evaluator] == 'future'
          evaluating_parser(environment)
        else
          eparser(environment)
        end
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

    # Returns an instance of an EvaluatingParser
    def self.evaluating_parser(file_watcher)
      # Since RGen is optional, test that it is installed
      @@asserted ||= false
      assert_rgen_installed() unless @@asserted
      @@asserted = true
      require 'puppet/parser/e4_parser_adapter'
      require 'puppet/pops/parser/code_merger'
      E4ParserAdapter.new(file_watcher)
    end

    # Creates an instance of the expression based parser 'eparser'
    #
    def self.eparser(environment)
      # Since RGen is optional, test that it is installed
      @@asserted ||= false
      assert_rgen_installed() unless @@asserted
      @@asserted = true
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

    def self.code_merger
      if Puppet[:parser] == 'future' && Puppet[:evaluator] == 'future'
        Puppet::Pops::Parser::CodeMerger.new
      else
        Puppet::Parser::CodeMerger.new
      end
    end

  end

end
