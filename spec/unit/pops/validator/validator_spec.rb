#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '../parser/parser_rspec_helper')

describe "validating 4x" do
  include ParserRspecHelper
  include PuppetSpec::Pops

  let(:acceptor) { Puppet::Pops::Validation::Acceptor.new() }
  let(:validator) { Puppet::Pops::Validation::ValidatorFactory_4_0.new().validator(acceptor) }

  def validate(model)
    validator.validate(model)
    acceptor
  end

  it 'should raise error for illegal names' do
    expect(validate(parse('class aaa::_bbb {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('class Aaa {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
  end

  it 'should raise error for illegal variable names' do
    expect(validate(fqn('Aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('AAA').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('aaa::_aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

  it 'should not raise error for variable name with underscore first in first name segment' do
    expect(validate(fqn('_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('::_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

  context 'for non productive expressions' do
    [ '1',
      '3.14',
      "'a'",
      '"a"',
      '"${$a=10}"', # interpolation with side effect
      'false',
      'true',
      'default',
      'undef',
      '[1,2,3]',
      '{a=>10}',
      'if 1 {2}',
      'if 1 {2} else {3}',
      'if 1 {2} elsif 3 {4}',
      'unless 1 {2}',
      'unless 1 {2} else {3}',
      '1 ? 2 => 3',
      '1 ? { 2 => 3}',
      '-1',
      '-foo()', # unary minus on productive
      '1+2',
      '1<2',
      '(1<2)',
      '!true',
      '!foo()', # not on productive
      '$a',
      '$a[1]',
      'name',
      'Type',
      'Type[foo]'
      ].each do |expr|
      it "produces error for non productive: #{expr}" do
        source = "#{expr}; $a = 10"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end

      it "does not produce error when last for non productive: #{expr}" do
        source = " $a = 10; #{expr}"
        expect(validate(parse(source))).to_not have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end
    end

    [
      'if 1 {$a = 1}',
      'if 1 {2} else {$a=1}',
      'if 1 {2} elsif 3 {$a=1}',
      'unless 1 {$a=1}',
      'unless 1 {2} else {$a=1}',
      '$a = 1 ? 2 => 3',
      '$a = 1 ? { 2 => 3}',
      'Foo[a] -> Foo[b]',
      '($a=1)',
      'foo()',
      '$a.foo()'
      ].each do |expr|

      it "does not produce error when for productive: #{expr}" do
        source = "#{expr}; $x = 1"
        expect(validate(parse(source))).to_not have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end
    end

    ['class', 'define', 'node'].each do |type|
      it "flags non productive expression last in #{type}" do
        source = <<-SOURCE
          #{type} nope {
            1
          }
          end
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::IDEM_NOT_ALLOWED_LAST)
      end
    end
  end

  context 'for reserved words' do
    ['function', 'private', 'type', 'attr'].each do |word|
      it "produces an error for the word '#{word}'" do
        source = "$a = #{word}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_WORD)
      end
    end
  end

  context 'for future reserved words' do
    ['application', 'produces', 'consumes'].each do |word|
      it "produces an issue for the word '#{word}'" do
        source = "$a = #{word}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::FUTURE_RESERVED_WORD)
      end

      it 'produces a warning issue when used as a class name' do
        source = "class #{word} {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::FUTURE_RESERVED_WORD)
      end

      it 'produces no warning or error when used as a parameter name' do
        source = "define foo($#{word}) { notice $#{word} }"
        expect(validate(parse(source)).diagnostics.empty?).to eq(true)
      end

      it 'produces no warning or error when used as an attribute name' do
        source = "foo { bar: #{word} => ok }"
        expect(validate(parse(source)).diagnostics.empty?).to eq(true)
      end
    end
  end

  context 'for reserved type names' do
    [# type/Type, is a reserved name but results in syntax error because it is a keyword in lower case form
    'any',
    'unit',
    'scalar',
    'boolean',
    'numeric',
    'integer',
    'float',
    'collection',
    'array',
    'hash',
    'tuple',
    'struct',
    'variant',
    'optional',
    'enum',
    'regexp',
    'pattern',
    'runtime',
    ].each do |name|

      it "produces an error for 'class #{name}'" do
        source = "class #{name} {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_TYPE_NAME)
      end

      it "produces an error for 'define #{name}'" do
        source = "define #{name} {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_TYPE_NAME)
      end
    end
  end

  context 'for parameter names' do
    ['class', 'define'].each do |word|
      it "should require that #{word} parameter names are unique" do
        expect(validate(parse("#{word} foo($a = 10, $a = 20) {}"))).to have_issue(Puppet::Pops::Issues::DUPLICATE_PARAMETER)
      end
    end

    it "should require that template parameter names are unique" do
      expect(validate(parse_epp("<%-| $a, $a |-%><%= $a == doh %>"))).to have_issue(Puppet::Pops::Issues::DUPLICATE_PARAMETER)
    end
  end

  context 'for reserved parameter names' do
    ['name', 'title'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_PARAMETER)
      end

      it "produces an error when $#{word} is used as a parameter in a define" do
        source = "define x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_PARAMETER)
      end
    end

  end

  context 'for numeric parameter names' do
    ['1', '0x2', '03'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NUMERIC_PARAMETER)
      end
    end
  end

  context 'for badly formed non-numeric parameter names' do
    ['Ateam', 'a::team'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end

      it "produces an error when $#{word} is used as a parameter in a define" do
        source = "define x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end

      it "produces an error when $#{word} is used as a parameter in a lambda" do
        source = "with() |$#{word}| {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end
    end
  end

  context 'top level constructs in conditionals' do
    ['class', 'define', 'node'].each do |word|
      it "produces an error when $#{word} is nested in an if expression" do
        source = "if true { #{word} x {} }"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::NOT_TOP_LEVEL)
      end
    end

    ['class', 'define', 'node'].each do |word|
      it "produces an error when $#{word} is nested in an if-else expression" do
        source = "if false {} else { #{word} x {} }"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::NOT_TOP_LEVEL)
      end
    end

    ['class', 'define', 'node'].each do |word|
      it "produces an error when $#{word} is nested in an unless expression" do
        source = "unless false { #{word} x {} }"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::NOT_TOP_LEVEL)
      end
    end
  end

  def parse(source)
    Puppet::Pops::Parser::Parser.new().parse_string(source)
  end
end
