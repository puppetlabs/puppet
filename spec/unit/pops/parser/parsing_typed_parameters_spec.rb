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

  let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }

  context "captures-rest parameter" do
    it 'is allowed in lambda when placed last' do
      source = <<-CODE
        foo() |$a, *$b| { $a + $b[0] }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to_not raise_error()
    end

    it 'allows a type annotation' do
      source = <<-CODE
        foo() |$a, Integer *$b| { $a + $b[0] }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to_not raise_error()
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
        define foo(*$a) { }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a has 'captures rest' - not supported in a 'define'/)
    end

    it 'is not allowed in class' do
      source = <<-CODE
        class foo(*$a) { }
      CODE
      expect do
        parser.parse_string(source, __FILE__)
      end.to raise_error(Puppet::ParseError, /Parameter \$a has 'captures rest' - not supported in a Host Class Definition/)
    end
  end
end
