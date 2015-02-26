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
      # Since RGen is optional, test that it is installed
      assert_rgen_installed()
      unless defined?(Puppet::Pops::Parser::E4ParserAdapter)
        require 'puppet/parser/e4_parser_adapter'
        require 'puppet/pops/parser/code_merger'
      end
      E4ParserAdapter.new
    end

    # Asserts that RGen >= 0.6.6 is installed by checking that certain behavior is available.
    # Note that this assert is expensive as it also requires puppet/pops (if not already loaded).
    #
    def self.assert_rgen_installed
      @@asserted ||= false
      return if @@asserted
      @@asserted = true
      begin
        require 'rgen/metamodel_builder'
      rescue LoadError
        raise Puppet::DevError.new("The gem 'rgen' version >= 0.7.0 is required when using the setting '--parser future'. Please install 'rgen'.")
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
      rescue => e
        # TODO: RGen can raise exceptions for other reasons!
        raise Puppet::DevError.new("The gem 'rgen' version >= 0.7.0 is required when using '--parser future'. An older version is installed, please update.")
      end
    end

    def self.code_merger
      Puppet::Pops::Parser::CodeMerger.new
    end
  end
end
