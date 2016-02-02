require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/json_strict_literal_evaluator'

describe "Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator" do
  let(:parser) {  Puppet::Pops::Parser::EvaluatingParser.new }
  let(:leval)  {  Puppet::Pops::Evaluator::JsonStrictLiteralEvaluator.new }

  { "1"       => 1,
    "3.14"    => 3.14,
    "true"    => true,
    "false"   => false,
    "'1'"     => '1',
    "'a'"     => 'a',
    '"a"'     => 'a',
    'a'       => 'a',
    'a::b'    => 'a::b',
    'undef'   => nil,

    # collections
    '[1,2,3]'     => [1,2,3],
    '{a=>1,b=>2}' => {'a' => 1, 'b' => 2},
    '[undef]'     => [nil],
    '{a=>undef}'  => { 'a' => nil }

  }.each do |source, result|
    it "evaluates '#{source}' to #{result}" do
      expect(leval.literal(parser.parse_string(source))).to eq(result)
    end
  end

  [ '1+1', 
    'File',
    '[1,2, 1+2]',
    '{a=>1+1}', 
    'Integer[1]', 
    '"x$y"', 
    '"x${y}z"'
  ].each do |source|
    it "throws :not_literal for non literal expression '#{source}'" do
      expect{leval.literal(parser.parse_string('1+1'))}.to throw_symbol(:not_literal)
    end
  end

  [ 'default', 
    '/.*/', 
    '{1=>100}', 
    '{undef => 10}',
    '{default => 10}',
    '{/.*/ => 10}',
    '{"ok" => {1 => 100}}',
    '[default]',
    '[[default]]',
    '[/.*/]',
    '[[/.*/]]',
    '[{1 => 100}]',
  ].each do |source|
    it "throws :not_literal for values not representable as pure JSON '#{source}'" do
      expect{leval.literal(parser.parse_string('1+1'))}.to throw_symbol(:not_literal)
    end
  end
end
