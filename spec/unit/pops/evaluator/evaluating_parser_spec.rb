#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet_spec/pops'
require 'puppet_spec/scope'


# relative to this spec file (./) does not work as this file is loaded by rspec
#require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include PuppetSpec::Pops
  include PuppetSpec::Scope

  let(:parser) { Puppet::Pops::Parser::EvaluatingParser::Transitional.new }
  let(:node) { 'node.example.com' }
  let(:scope) { s = create_test_scope_for_node(node); s }
  types = Puppet::Pops::Types::TypeFactory

  context "When evaluator evaluates literals" do
    {
      "1"             => 1,
      "010"           => 8,
      "0x10"          => 16,
      "3.14"          => 3.14,
      "0.314e1"       => 3.14,
      "31.4e-1"       => 3.14,
      "'1'"           => '1',
      "'banana'"      => 'banana',
      '"banana"'      => 'banana',
      "banana"        => 'banana',
      "banana::split" => 'banana::split',
      "false"         => false,
      "true"          => true,
      "Array"         => types.array_of_data(),
      "/.*/"          => /.*/
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end
  end

  context "When the evaluator evaluates Lists and Hashes" do
    {
      "[]"                                              => [],
      "[1,2,3]"                                         => [1,2,3],
      "[1,[2.0, 2.1, [2.2]],[3.0, 3.1]]"                => [1,[2.0, 2.1, [2.2]],[3.0, 3.1]],
      "[2 + 2]"                                         => [4],
      "[1,2,3] == [1,2,3]"                              => true,
      "[1,2,3] != [2,3,4]"                              => true,
      "[1,2,3] == [2,2,3]"                              => false,
      "[1,2,3] != [1,2,3]"                              => false,
      "[1,2,3][2]"                                      => 3,
      "[1,2,3] + [4,5]"                                 => [1,2,3,4,5],
      "[1,2,3] + [[4,5]]"                               => [1,2,3,[4,5]],
      "[1,2,3] + {'a' => 1, 'b'=>2}"                    => [1,2,3,['a',1],['b',2]],
      "[1,2,3] + 4"                                     => [1,2,3,4],
      "[1,2,3] << [4,5]"                                => [1,2,3,[4,5]],
      "[1,2,3] << {'a' => 1, 'b'=>2}"                   => [1,2,3,{'a' => 1, 'b'=>2}],
      "[1,2,3] << 4"                                    => [1,2,3,4],
      "[1,2,3,4] - [2,3]"                               => [1,4],
      "[1,2,3,4] - [2,5]"                               => [1,3,4],
      "[1,2,3,4] - 2"                                   => [1,3,4],
      "[1,2,3,[2],4] - 2"                               => [1,3,[2],4],
      "[1,2,3,[2,3],4] - [[2,3]]"                       => [1,2,3,4],
      "[1,2,3,3,2,4,2,3] - [2,3]"                       => [1,4],
      "[1,2,3,['a',1],['b',2]] - {'a' => 1, 'b'=>2}"    => [1,2,3],
      "[1,2,3,{'a'=>1,'b'=>2}] - [{'a' => 1, 'b'=>2}]"  => [1,2,3],
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "[1,2,3][a]" => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    {
      "{}"                                       => {},
      "{'a'=>1,'b'=>2}"                          => {'a'=>1,'b'=>2},
      "{'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}"        => {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}},
      "{'a'=> 2 + 2}"                            => {'a'=> 4},
      "{'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2}"   => true,
      "{'a'=> 1, 'b'=>2} != {'x'=> 1, 'b'=>2}"   => true,
      "{'a'=> 1, 'b'=>2} == {'a'=> 2, 'b'=>3}"   => false,
      "{'a'=> 1, 'b'=>2} != {'a'=> 1, 'b'=>2}"   => false,
      "{a => 1, b => 2}[b]"                      => 2,
      "{2+2 => sum, b => 2}[4]"                  => 'sum',
      "{'a'=>1, 'b'=>2} + {'c'=>3}"              => {'a'=>1,'b'=>2,'c'=>3},
      "{'a'=>1, 'b'=>2} + {'b'=>3}"              => {'a'=>1,'b'=>3},
      "{'a'=>1, 'b'=>2} + ['c', 3, 'b', 3]"      => {'a'=>1,'b'=>3, 'c'=>3},
      "{'a'=>1, 'b'=>2} + [['c', 3], ['b', 3]]"  => {'a'=>1,'b'=>3, 'c'=>3},
      "{'a'=>1, 'b'=>2} - {'b' => 3}"            => {'a'=>1},
      "{'a'=>1, 'b'=>2, 'c'=>3} - ['b', 'c']"    => {'a'=>1},
      "{'a'=>1, 'b'=>2, 'c'=>3} - 'c'"           => {'a'=>1, 'b'=>2},
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "{'a' => 1, 'b'=>2} << 1" => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When the evaluator perform comparisons" do
    {
      "'a' == 'a'"     => true,
      "'a' == 'b'"     => false,
      "'a' != 'a'"     => false,
      "'a' != 'b'"     => true,
      "'a' < 'b' "     => true,
      "'a' < 'a' "     => false,
      "'b' < 'a' "     => false,
      "'a' <= 'b'"     => true,
      "'a' <= 'a'"     => true,
      "'b' <= 'a'"     => false,
      "'a' > 'b' "     => false,
      "'a' > 'a' "     => false,
      "'b' > 'a' "     => true,
      "'a' >= 'b'"     => false,
      "'a' >= 'a'"     => true,
      "'b' >= 'a'"     => true,
      "'a' == 'A'"     => true,
      "'a' != 'A'"     => false,
      "'a' >  'A'"     => false,
      "'a' >= 'A'"     => true,
      "'A' <  'a'"     => false,
      "'A' <= 'a'"     => true,
      "1 == 1"         => true,
      "1 == 2"         => false,
      "1 != 1"         => false,
      "1 != 2"         => true,
      "1 < 2 "         => true,
      "1 < 1 "         => false,
      "2 < 1 "         => false,
      "1 <= 2"         => true,
      "1 <= 1"         => true,
      "2 <= 1"         => false,
      "1 > 2 "         => false,
      "1 > 1 "         => false,
      "2 > 1 "         => true,
      "1 >= 2"         => false,
      "1 >= 1"         => true,
      "2 >= 1"         => true,
      "1 == 1.0 "      => true,
      "1 < 1.1  "      => true,
      "'1' < 1.1"      => true,
      "1.0 == 1 "      => true,
      "1.0 < 2  "      => true,
      "'1.0' < 1.1"    => true,
      "'1.0' < 'a'"    => true,
      "'1.0' < '' "    => true,
      "'1.0' < ' '"    => true,
      "'a' > '1.0'"    => true,
      "/.*/ == /.*/ "  => true,
      "/.*/ != /a.*/"  => true,
      "true  == true " => true,
      "false == false" => true,
      "true == false"  => false,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

   {
      "'a' =~ /.*/"                 => true,
      "'a' =~ '.*'"                 => true,
      "/.*/ != /a.*/"               => true,
      "'a' !~ /b.*/"                => true,
      "'a' !~ 'b.*'"                => true,
      '$x = a; a =~ "$x.*"'         => true,
      "a =~ Pattern['a.*']"         => true,
      "$x = /a.*/ a =~ $x"          => true,
      "$x = Pattern['a.*'] a =~ $x" => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "666 =~ /6/"    => :error,
      "[a] =~ /a/"    => :error,
      "{a=>1} =~ /a/" => :error,
      "/a/ =~ /a/"    => :error,
      "Array =~ /A/"  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    {
      "1 in [1,2,3]"                  => true,
      "4 in [1,2,3]"                  => false,
      "a in {x=>1, a=>2}"             => true,
      "z in {x=>1, a=>2}"             => false,
      "ana in bananas"                => true,
      "xxx in bananas"                => false,
      "/ana/ in bananas"              => true,
      "/xxx/ in bananas"              => false,
      "ANA in bananas"                => false, # ANA is a type, not a String
      "'ANA' in bananas"              => true,
      "ana in 'BANANAS'"              => true,
      "/ana/ in 'BANANAS'"            => false,
      "/ANA/ in 'BANANAS'"            => true,
      "xxx in 'BANANAS'"              => false,
      "[2,3] in [1,[2,3],4]"          => true,
      "[2,4] in [1,[2,3],4]"          => false,
      "[a,b] in ['A',['A','B'],'C']"  => true,
      "[x,y] in ['A',['A','B'],'C']"  => false,
      "a in {a=>1}"                   => true,
      "x in {a=>1}"                   => false,
      "'A' in {a=>1}"                 => true,
      "'X' in {a=>1}"                 => false,
      "a in {'A'=>1}"                 => true,
      "x in {'A'=>1}"                 => false,
      "/xxx/ in {'aaaxxxbbb'=>1}"     => true,
      "/yyy/ in {'aaaxxxbbb'=>1}"     => false,
      "15 in [1, 0xf]"                => true,
      "15 in [1, '0xf']"              => true,
      "'15' in [1, 0xf]"              => true,
      "15 in [1, 115]"                => false,
      "1 in [11, '111']"              => false,
      "'1' in [11, '111']"            => false,
      "Array[Integer] in [2, 3]"      => false,
      "Array[Integer] in [2, [3, 4]]" => true,
      "Array[Integer] in [2, [a, 4]]" => false,
      "Integer in { 2 =>'a'}"         => true,
      "Integer in {'a'=>'a'}"         => false,
      "Integer in {'a'=>1}"           => false,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

  end

  context "When the evaluator performs arithmetic" do
    context "on Integers" do
      {  "2+2"    => 4,
         "2 + 2"  => 4,
         "7 - 3"  => 4,
         "6 * 3"  => 18,
         "6 / 3"  => 2,
         "6 % 3"  => 0,
         "10 % 3" =>  1,
         "-(6/3)" => -2,
         "-6/3  " => -2,
         "8 >> 1" => 4,
         "8 << 1" => 16,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

    context "on Floats" do
      {
        "2.2 + 2.2"  => 4.4,
        "7.7 - 3.3"  => 4.4,
        "6.1 * 3.1"  => 18.91,
        "6.6 / 3.3"  => 2.0,
        "6.6 % 3.3"  => 0.0,
        "10.0 % 3.0" =>  1.0,
        "-(6.0/3.0)" => -2.0,
        "-6.0/3.0 "  => -2.0,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

      {
        "3.14 << 2" => :error,
        "3.14 >> 2" => :error,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
    end

    context "on strings requiring boxing to Numeric" do
      {
        "'2' + '2'"       => 4,
        "'2.2' + '2.2'"   => 4.4,
        "'0xF7' + '010'"  => 0xFF,
        "'0xF7' + '0x8'"  => 0xFF,
        "'0367' + '010'"  => 0xFF,
        "'012.3' + '010'" => 20.3,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            parser.evaluate_string(scope, source, __FILE__).should == result
          end
        end

      {
        "'0888' + '010'"   => :error,
        "'0xWTF' + '010'"  => :error,
        "'0x12.3' + '010'" => :error,
        "'0x12.3' + '010'" => :error,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
      end
    end
  end # arithmetic

  context "When the evaluator evaluates conditionals" do
    {
      "if true {5}"                     => 5,
      "if false {5}"                    => nil,
      "if false {2} else {5}"           => 5,
      "if false {2} elsif true {5}"     => 5,
      "if false {2} elsif false {5}"    => nil,
      "unless false {5}"                => 5,
      "unless true {5}"                 => nil,
      "unless true {2} else {5}"        => 5,
      "$a = if true {5} $a"                     => 5,
      "$a = if false {5} $a"                    => nil,
      "$a = if false {2} else {5} $a"           => 5,
      "$a = if false {2} elsif true {5} $a"     => 5,
      "$a = if false {2} elsif false {5} $a"    => nil,
      "$a = unless false {5} $a"                => 5,
      "$a = unless true {5} $a"                 => nil,
      "$a = unless true {2} else {5} $a"        => 5,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "case 1 { 1 : { yes } }"                               => 'yes',
      "case 2 { 1,2,3 : { yes} }"                            => 'yes',
      "case 2 { 1,3 : { no } 2: { yes} }"                    => 'yes',
      "case 2 { 1,3 : { no } 5: { no } default: { yes }}"    => 'yes',
      "case 2 { 1,3 : { no } 5: { no } }"                    => nil,
      "case 'banana' { 1,3 : { no } /.*ana.*/: { yes } }"    => 'yes',
      "case 'banana' { /.*(ana).*/: { $1 } }"                => 'ana',
      "case [1] { Array : { yes } }"                         => 'yes',
      "case [1] {
         Array[String] : { no }
         Array[Integer]: { yes }
      }"                                                     => 'yes',
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "2 ? { 1 => no, 2 => yes}"                          => 'yes',
      "3 ? { 1 => no, 2 => no}"                           => nil,
      "3 ? { 1 => no, 2 => no, default => yes }"          => 'yes',
      "3 ? { 1 => no, default => yes, 3 => no }"          => 'yes',
      "'banana' ? { /.*(ana).*/  => $1 }"                 => 'ana',
      "[2] ? { Array[String] => yes, Array => yes}"       => 'yes',
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end
  end

  context "When evaluator performs [] operations" do
    {
      "[1,2,3][0]"      => 1,
      "[1,2,3][2]"      => 3,
      "[1,2,3][3]"      => nil,
      "[1,2,3][-1]"     => 3,
      "[1,2,3][-2]"     => 2,
      "[1,2,3][-4]"     => nil,
      "[1,2,3,4][0,2]"  => [1,2],
      "[1,2,3,4][1,3]"  => [2,3,4],
      "[1,2,3,4][-2,2]"  => [3,4],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    {
      "{a=>1, b=>2, c=>3}[a]"      => 1,
      "{a=>1, b=>2, c=>3}[c]"      => 3,
      "{a=>1, b=>2, c=>3}[x]"      => nil,
      "{a=>1, b=>2, c=>3}[c,b]"    => [3,2],
      "{a=>1, b=>2, c=>3}[a,b,c]"  => [1,2,3],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    {
      "'abc'[0]"      => 'a',
      "'abc'[2]"      => 'c',
      "'abc'[-1]"     => 'c',
      "'abc'[-2]"     => 'b',
      "'abc'[-3]"     => 'a',
      "'abc'[-4]"     => nil,
      "'abc'[3]"      => nil,
      "abc[0]"        => 'a',
      "abc[2]"        => 'c',
      "abc[-1]"       => 'c',
      "abc[-2]"       => 'b',
      "abc[-3]"       => 'a',
      "abc[-4]"       => nil,
      "abc[3]"        => nil,
      "'abcd'[0,2]"   => 'ab',
      "'abcd'[1,3]"   => 'bcd',
      "'abcd'[-2,2]"  => 'cd',
      "'abcd'[-3,2]"  => 'bc',
      "'abcd'[3,5]"   => 'd',
      "'abcd'[5,2]"   => nil,
      "'abcd'[-5,2]" => nil,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    # Type operations (full set tested by tests covering type calculator)
    {
      "Array[Integer]"             => types.array_of(types.integer),
      "Hash[Integer,Integer]"      => types.hash_of(types.integer, types.integer),
      "Resource[File]"             => types.resource('File'),
      "Resource['File']"           => types.resource(types.resource('File')),
      "File[foo]"                  => types.resource('file', 'foo'),
      "File[foo, bar]"             => [types.resource('file', 'foo'), types.resource('file', 'bar')],
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end

    # Resource default and override expressions and resource parameter access
    {
      "notify { id: message=>explicit} Notify[id][message]"                   => "explicit",
      "Notify { message=>by_default} notify {foo:} Notify[foo][message]"      => "by_default",
      "notify {foo:} Notify[foo]{message =>by_override} Notify[foo][message]" => "by_override",
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        parser.evaluate_string(scope, source, __FILE__).should == result
      end
    end
    # Resource default and override expressions and resource parameter access
    {
      "notify { xid: message=>explicit} Notify[id][message]"                  => /Resource not found/,
      "notify { id: message=>explicit} Notify[id][mustard]"                   => /does not have a parameter called 'mustard'/,
    }.each do |source, result|
      it "should parse '#{source}' and raise error matching #{result}" do
        expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(result)
      end
    end
  end

  context "When the evaluator performs boolean operations" do
    {
      "true and true"   => true,
      "false and true"  => false,
      "true and false"  => false,
      "false and false" => false,
      "true or true"    => true,
      "false or true"   => true,
      "true or false"   => true,
      "false or false"  => false,
      "! true"          => false,
      "!! true"         => true,
      "!! false"        => false,
      "! 'x'"           => false,
      "! ''"            => true,
      "! undef"         => true,
      "! [a]"           => false,
      "! []"            => false,
      "! {a=>1}"        => false,
      "! {}"            => false,
      "true and false and '0xwtf' + 1"  => false,
      "false or true  or '0xwtf' + 1"  => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      "false || false || '0xwtf' + 1"   => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluator performs calls" do
    let(:populate) do
      parser.evaluate_string(scope, "$a = 10 $b = [1,2,3]")
    end

    {
      'sprintf( "x%iy", $a )'                 => "x10y",
      '"x%iy".sprintf( $a )'                  => "x10y",
      '$b.reduce |$memo,$x| { $memo + $x }'   => 6,
      'reduce($b) |$memo,$x| { $memo + $x }'  => 6,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluator performs string interpolation" do
    let(:populate) do
      parser.evaluate_string(scope, "$a = 10 $b = [1,2,3]")
    end

    {
      '"value is $a yo"'                      => "value is 10 yo",
      '"value is \$a yo"'                     => "value is $a yo",
      '"value is ${a} yo"'                    => "value is 10 yo",
      '"value is \${a} yo"'                   => "value is ${a} yo",
      '"value is ${$a} yo"'                   => "value is 10 yo",
      '"value is ${$a*2} yo"'                 => "value is 20 yo",
      '"value is ${sprintf("x%iy",$a)} yo"'   => "value is x10y yo",
      '"value is ${"x%iy".sprintf($a)} yo"'   => "value is x10y yo",
      '"value is ${[1,2,3]} yo"'              => "value is [1, 2, 3] yo",
      '"value is ${{a=>1,b=>2}} yo"'          => "value is {a => 1, b => 2} yo",
      '"value is ${/.*/} yo"'                 => "value is /.*/ yo",
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

end
