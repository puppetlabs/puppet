require 'puppet/pops'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')

module ParserRspecHelper
  include FactoryRspecHelper

  def with_app_management(flag)
    # Horrible things have to be done to test this as the Lexer sets up the
    # KEYWORD table as a frozen constant, and this list depends on the
    # Puppet[:app_management] setting. These 'before all' and 'after all'
    # clauses forces Ruby to reload the Lexer
    Puppet[:app_management] = flag
    Puppet::Pops::Parser.send(:remove_const, :Lexer2)
    if Puppet::Parser.const_defined?(:E4ParserAdapter)
      Puppet::Parser::E4ParserAdapter.class_variable_set(:@@evaluating_parser, nil)
    end
    load 'puppet/pops/parser/lexer2.rb'
  end

  def parse(code)
    parser = Puppet::Pops::Parser::Parser.new()
    parser.parse_string(code)
  end
end
