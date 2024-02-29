require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/literal_evaluator'

describe "Puppet::Pops::Evaluator::LiteralEvaluator" do
  let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }
  let(:leval)  {  Puppet::Pops::Evaluator::LiteralEvaluator.new }

  { "1"       => 1,
    "3.14"    => 3.14,
    "true"    => true,
    "false"   => false,
    "'1'"     => '1',
    "'a'"     => 'a',
    '"a"'     => 'a',
    'a'       => 'a',
    'a::b'    => 'a::b',
    'Boolean[true]' => [true],
    'Integer[1]' => [1],
    'Integer[-1]' => [-1],
    'Integer[-5, -1]' => [-5, -1],
    'Integer[-5, 5]'  => [-5, 5],
    # we can't actually represent MIN_INTEGER because it's glexed as
    # UnaryMinusExpression containing a positive LiteralInteger and the integer
    # must be <= MAX_INTEGER
    "Integer[#{Puppet::Pops::MIN_INTEGER + 1}]" => [-0x7FFFFFFFFFFFFFFF],
    "Integer[0, #{Puppet::Pops::MAX_INTEGER}]"  => [0, 0x7FFFFFFFFFFFFFFF],
    'Integer[0, default]'         => [0, :default],
    'Integer[Infinity]'           => ['infinity'],
    'Float[Infinity]'             => ['infinity'],
    'Array[Integer, 1]'           => ['integer', 1],
    'Hash[Integer, String, 1, 3]' => ['integer', 'string', 1, 3],
    'Regexp[/-1/]'                => [/-1/],
    'Sensitive[-1]'               => [-1],
    'Timespan[-5, 5]'             => [-5, 5],
    'Timestamp["2012-10-10", 1]'  => ['2012-10-10', 1],
    'Undef' => 'undef',
    'File' => "file",

    # special values
    'default' => :default,
    '/.*/'    => /.*/,

    # collections
    '[1,2,3]'     => [1,2,3],
    '{a=>1,b=>2}' => {'a' => 1, 'b' => 2},

  }.each do |source, result|
    it "evaluates '#{source}' to #{result}" do
      expect(leval.literal(parser.parse_string(source))).to eq(result)
    end
  end

  it "evaluates undef to nil" do
    expect(leval.literal(parser.parse_string('undef'))).to be_nil
  end

  [ '',
    '1+1',
    '[1,2, 1+2]',
    '{a=>1+1}',
    '"x$y"',
    '"x${y}z"',
    'Integer[1-3]',
    'Integer[-1-3]',
    'Optional[[String]]'
  ].each do |source|
    it "throws :not_literal for non literal expression '#{source}'" do
      expect{leval.literal(parser.parse_string(source))}.to throw_symbol(:not_literal)
    end
  end
end
