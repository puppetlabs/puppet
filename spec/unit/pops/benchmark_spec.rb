#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe "Benchmark", :benchmark => true do

    def code
      'if true
{
$a = 10 + 10
}
else
{
$a = "interpolate ${foo} and stuff"
}
'    end

  it "transformer", :profile => true do
    parser = Puppet::Pops::Parser::Parser.new()
    model = parser.parse_string(code).current
    transformer = Puppet::Pops::Model::AstTransformer.new()
    m = Benchmark.measure { 10000.times { transformer.transform(model) }}
    puts "Transformer: #{m}"
  end

  it "validator", :profile => true do
    parser = Puppet::Pops::Parser::EvaluatingParser.new()
    model = parser.parse_string(code)
    m = Benchmark.measure { 100000.times { parser.assert_and_report(model) }}
    puts "Validator: #{m}"
  end

  it "parse transform", :profile => true do
    parser = Puppet::Pops::Parser::Parser.new()
    transformer = Puppet::Pops::Model::AstTransformer.new()
    m = Benchmark.measure { 10000.times { transformer.transform(parser.parse_string(code).current) }}
    puts "Parse and transform: #{m}"
  end

  it "parser0", :profile => true do
    parser = Puppet::Parser::Parser.new('test')
    m = Benchmark.measure { 10000.times { parser.parse(code) }}
    puts "Parser 0: #{m}"
  end

  it "parser1", :profile => true do
    parser = Puppet::Pops::Parser::EvaluatingParser.new()
    m = Benchmark.measure { 10000.times { parser.parse_string(code) }}
    puts "Parser1: #{m}"
  end

  it "lexer2", :profile => true do
    lexer = Puppet::Pops::Parser::Lexer2.new
     m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
     puts "Lexer2: #{m}"
  end

  it "lexer1", :profile => true do
    lexer = Puppet::Pops::Parser::Lexer.new
    m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
    puts "Pops Lexer: #{m}"
  end

  it "lexer0", :profile => true do
    lexer = Puppet::Parser::Lexer.new
    m = Benchmark.measure {10000.times {lexer.string = code; lexer.fullscan }}
    puts "Original Lexer: #{m}"
  end
end
