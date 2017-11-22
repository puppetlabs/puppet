#! /usr/bin/env ruby
require 'spec_helper'

describe "the sprintf function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("sprintf")).to eq("function_sprintf")
  end

  it "should raise an ArgumentError if there is less than 1 argument" do
    expect { @scope.function_sprintf([]) }.to( raise_error(ArgumentError))
  end

  it "should format integers" do
    result = @scope.function_sprintf(["%+05d", "23"])
    expect(result).to(eql("+0023"))
  end

  it "should format floats" do
    result = @scope.function_sprintf(["%+.2f", "2.7182818284590451"])
    expect(result).to(eql("+2.72"))
  end

  it "should format large floats" do
    result = @scope.function_sprintf(["%+.2e", "27182818284590451"])
    str =
      "+2.72e+16"
    expect(result).to(eql(str))
  end

  it "should perform more complex formatting" do
    result = @scope.function_sprintf(
      [ "<%.8s:%#5o %#8X (%-8s)>",
        "overlongstring", "23", "48879", "foo" ])
    expect(result).to(eql("<overlong:  027   0XBEEF (foo     )>"))
  end

  it 'does not attempt to mutate its arguments' do
    args = ['%d', 1].freeze
    expect { @scope.function_sprintf(args) }.to_not raise_error
  end

  it 'support named arguments in a hash with string keys' do
    result = @scope.function_sprintf(["%<foo>d : %<bar>f", {'foo' => 1, 'bar' => 2}])
    expect(result).to eq("1 : 2.000000")
  end

  it 'raises a key error if a key is not present' do
    expect do
      @scope.function_sprintf(["%<foo>d : %<zanzibar>f", {'foo' => 1, 'bar' => 2}])
    end.to raise_error(KeyError, /key<zanzibar> not found/)
  end

  it 'a hash with string keys that is output formats as strings' do
    result = @scope.function_sprintf(["%s", {'foo' => 1, 'bar' => 2}])
    expect(result).to eq("{\"foo\"=>1, \"bar\"=>2}")
  end

  it 'named arguments hash with non string keys are tolerated' do
    result = @scope.function_sprintf(["%<foo>d : %<bar>f", {'foo' => 1, 'bar' => 2, 1 => 2, [1] => 2, false => true, {} => {}}])
    expect(result).to eq("1 : 2.000000")
  end

end
