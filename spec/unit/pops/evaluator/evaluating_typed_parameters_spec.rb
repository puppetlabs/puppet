require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'puppet/parser/e4_parser_adapter'


# relative to this spec file (./) does not work as this file is loaded by rspec
#require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include PuppetSpec::Pops
  include PuppetSpec::Scope
  before(:each) do
    Puppet[:strict_variables] = true

    # These must be set since the is 3x logic that triggers on these even if the tests are explicit
    # about selection of parser and evaluator
    #
    Puppet[:parser] = 'future'
    Puppet[:evaluator] = 'future'
    # Puppetx cannot be loaded until the correct parser has been set (injector is turned off otherwise)
    require 'puppetx'
  end

  let(:parser) {  Puppet::Pops::Parser::EvaluatingParser::Transitional.new }
  let(:node) { 'node.example.com' }
  let(:scope) { s = create_test_scope_for_node(node); s }
  types = Puppet::Pops::Types::TypeFactory

  context "captures-rest parameter" do
    it 'is allowed in function when placed last' do
      pending 'puppet functions not yet supported'
      source = <<-CODE
        function foo($a, *$b) { $a + $b[0] }
      CODE
      parser.parse_string(source, __FILE__)
    end

    it 'is not allowed in function except last' do
      pending 'puppet functions not yet supported'
      source = <<-CODE
        function foo(*$a, $b) { $a + $b[0] }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a is not last, and has 'captures rest'/)
    end

    it 'is allowed in lambda when placed last' do
      source = <<-CODE
        foo() |$a, *$b| { $a + $b[0] }
      CODE
      parser.parse_string(source, __FILE__)
    end

    it 'is not allowed in lambda except last' do
      source = <<-CODE
        foo() |*$a, $b| { $a + $b[0] }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a is not last, and has 'captures rest'/)
    end

    it 'is not allowed in define' do
      source = <<-CODE
        define foo(*$a, $b) { }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a has 'captures rest' - not supported in a 'define'/)
    end

    it 'is not allowed in class' do
      source = <<-CODE
        class foo(*$a, $b) { }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a has 'captures rest' - not supported in a Host Class Definition/)
    end

  end

  context 'foo' do
    {
      "1"             => 1,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end
  end
end
