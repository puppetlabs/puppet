require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet/loaders'
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
    Puppet[:data_binding_terminus] = 'none'

    # Tests needs a known configuration of node/scope/compiler since it parses and evaluates
    # snippets as the compiler will evaluate them, butwithout the overhead of compiling a complete
    # catalog for each tested expression.
    #
    @parser  = Puppet::Pops::Parser::EvaluatingParser.new
    @node = Puppet::Node.new('node.example.com')
    @node.environment = environment
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler)
    @scope.source = Puppet::Resource::Type.new(:node, 'node.example.com')
    @scope.parent = @compiler.topscope
  end

  let(:environment) { Puppet::Node::Environment.create(:testing, []) }
  let(:parser) { @parser }
  let(:scope) { @scope }
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
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
    end

    it 'should error when it encounters an unknown resource' do
      expect {parser.evaluate_string(scope, '$a = SantaClause', __FILE__)}.to raise_error(/Resource type not found: SantaClause/)
    end

    it 'should error when it encounters an unknown resource with a parameter' do
      expect {parser.evaluate_string(scope, '$b = ToothFairy[emea]', __FILE__)}.to raise_error(/Resource type not found: ToothFairy/)
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
      "[1,2,3, *[4,5]]"                                 => [1,2,3,4,5],
      "[1,2,3, (*[4,5])]"                               => [1,2,3,4,5],
      "[1,2,3, ((*[4,5]))]"                             => [1,2,3,4,5],
      "[1,2,3] + [[4,5]]"                               => [1,2,3,[4,5]],
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
      "[1,2,3] + {'a' => 1, 'b'=>2}"                    => [1,2,3,['a',1],['b',2]],
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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
      "1.0 == 1 "      => true,
      "1.0 < 2  "      => true,
      "'1.0' < 'a'"    => true,
      "'1.0' < '' "    => false,
      "'1.0' < ' '"    => false,
      "'a' > '1.0'"    => true,
      "/.*/ == /.*/ "  => true,
      "/.*/ != /a.*/"  => true,
      "true  == true " => true,
      "false == false" => true,
      "true == false"  => false,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

   {
     "a > 1" => /String > Integer/,
     "a >= 1" => /String >= Integer/,
     "a < 1" => /String < Integer/,
     "a <= 1" => /String <= Integer/,
     "1 > a" => /Integer > String/,
     "1 >= a" => /Integer >= String/,
     "1 < a" => /Integer < String/,
     "1 <= a" => /Integer <= String/,
   }.each do | source, error|
     it "should not allow comparison of String and Number '#{source}'" do
       expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(error)
     end
   end

   {
      "'a' =~ /.*/"                     => true,
      "'a' =~ '.*'"                     => true,
      "/.*/ != /a.*/"                   => true,
      "'a' !~ /b.*/"                    => true,
      "'a' !~ 'b.*'"                    => true,
      '$x = a; a =~ "$x.*"'             => true,
      "a =~ Pattern['a.*']"             => true,
      "a =~ Regexp['a.*']"              => false, # String is not subtype of Regexp. PUP-957
      "$x = /a.*/ a =~ $x"              => true,
      "$x = Pattern['a.*'] a =~ $x"     => true,
      "1 =~ Integer"                    => true,
      "1 !~ Integer"                    => false,
      "undef =~ NotUndef"               => false,
      "undef !~ NotUndef"               => true,
      "[1,2,3] =~ Array[Integer[1,10]]" => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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
      "FILE in profiler"              => false, # FILE is a type, not a String
      "'FILE' in profiler"            => true,
      "String[1] in bananas"          => false, # Philosophically true though :-)
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
      "15 in [1, '0xf']"              => false,
      "'15' in [1, 0xf]"              => false,
      "15 in [1, 115]"                => false,
      "1 in [11, '111']"              => false,
      "'1' in [11, '111']"            => false,
      "Array[Integer] in [2, 3]"      => false,
      "Array[Integer] in [2, [3, 4]]" => true,
      "Array[Integer] in [2, [a, 4]]" => false,
      "Integer in { 2 =>'a'}"         => true,
      "Integer[5,10] in [1,5,3]"      => true,
      "Integer[5,10] in [1,2,3]"      => false,
      "Integer in {'a'=>'a'}"         => false,
      "Integer in {'a'=>1}"           => false,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    {
      "if /(ana)/ in bananas {$1}" => 'ana',
      "if /(xyz)/ in bananas {$1} else {$1}" => nil,
      "$a = bananas =~ /(ana)/; $b = /(xyz)/ in bananas; $1" => 'ana',
      "$a = xyz =~ /(xyz)/; $b = /(ana)/ in bananas; $1" => 'ana',
      "if /p/ in [pineapple, bananas] {$0}" => 'p',
      "if /b/ in [pineapple, bananas] {$0}" => 'b',
    }.each do |source, result|
      it "sets match variables for a regexp search using in such that '#{source}' produces '#{result}'" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    {
      'Any'  => ['NotUndef', 'Data', 'Scalar', 'Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern', 'Collection',
                    'Array', 'Hash', 'CatalogEntry', 'Resource', 'Class', 'Undef', 'File' ],

      # Note, Data > Collection is false (so not included)
      'Data'    => ['Scalar', 'Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern', 'Array', 'Hash',],
      'Scalar' => ['Numeric', 'Integer', 'Float', 'Boolean', 'String', 'Pattern'],
      'Numeric' => ['Integer', 'Float'],
      'CatalogEntry' => ['Class', 'Resource', 'File'],
      'Integer[1,10]' => ['Integer[2,3]'],
    }.each do |general, specials|
      specials.each do |special |
        it "should compute that #{general} > #{special}" do
          expect(parser.evaluate_string(scope, "#{general} > #{special}", __FILE__)).to eq(true)
        end
        it "should compute that  #{special} < #{general}" do
          expect(parser.evaluate_string(scope, "#{special} < #{general}", __FILE__)).to eq(true)
        end
        it "should compute that #{general} != #{special}" do
          expect(parser.evaluate_string(scope, "#{special} != #{general}", __FILE__)).to eq(true)
        end
      end
    end

    {
      'Integer[1,10] > Integer[2,3]'   => true,
      'Integer[1,10] == Integer[2,3]'  => false,
      'Integer[1,10] > Integer[0,5]'   => false,
      'Integer[1,10] > Integer[1,10]'  => false,
      'Integer[1,10] >= Integer[1,10]' => true,
      'Integer[1,10] == Integer[1,10]' => true,
    }.each do |source, result|
        it "should parse and evaluate the integer range comparison expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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
            expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
          end
        end

    context "on Floats" do
      {
        "2.2 + 2.2"  => 4.4,
        "7.7 - 3.3"  => 4.4,
        "6.1 * 3.1"  => 18.91,
        "6.6 / 3.3"  => 2.0,
        "-(6.0/3.0)" => -2.0,
        "-6.0/3.0 "  => -2.0,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
          end
        end

      {
        "3.14 << 2" => :error,
        "3.14 >> 2" => :error,
        "6.6 % 3.3"  => 0.0,
        "10.0 % 3.0" =>  1.0,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
    end

    context "on strings requiring boxing to Numeric" do
      {
        "'2' + '2'"       => 4,
        "'-2' + '2'"      => 0,
        "'- 2' + '2'"     => 0,
        '"-\t 2" + "2"'   => 0,
        "'+2' + '2'"      => 4,
        "'+ 2' + '2'"     => 4,
        "'2.2' + '2.2'"   => 4.4,
        "'-2.2' + '2.2'"  => 0.0,
        "'0xF7' + '010'"  => 0xFF,
        "'0xF7' + '0x8'"  => 0xFF,
        "'0367' + '010'"  => 0xFF,
        "'012.3' + '010'" => 20.3,
        "'-0x2' + '0x4'"  => 2,
        "'+0x2' + '0x4'"  => 6,
        "'-02' + '04'"    => 2,
        "'+02' + '04'"    => 6,
      }.each do |source, result|
          it "should parse and evaluate the expression '#{source}' to #{result}" do
            expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
          end
        end

      {
        "'0888' + '010'"   => :error,
        "'0xWTF' + '010'"  => :error,
        "'0x12.3' + '010'" => :error,
        '"-\n 2" + "2"'    => :error,
        '"-\v 2" + "2"'    => :error,
        '"-2\n" + "2"'     => :error,
        '"-2\n " + "2"'    => :error,
      }.each do |source, result|
          it "should parse and raise error for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
          end
        end
      end
    end
  end # arithmetic

  context "When the evaluator evaluates assignment" do
    {
      "$a = 5"                     => 5,
      "$a = 5; $a"                 => 5,
      "$a = 5; $b = 6; $a"         => 5,
      "$a = $b = 5; $a == $b"      => true,
      "[$a] = 1 $a"                              => 1,
      "[$a] = [1] $a"                            => 1,
      "[$a, $b] = [1,2] $a+$b"                   => 3,
      "[$a, [$b, $c]] = [1,[2, 3]] $a+$b+$c"     => 6,
      "[$a] = {a => 1} $a"                       => 1,
      "[$a, $b] = {a=>1,b=>2} $a+$b"             => 3,
      "[$a, [$b, $c]] = {a=>1,[b,c] =>{b=>2, c=>3}} $a+$b+$c"     => 6,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

    [
      "[a,b,c] = [1,2,3]",
      "[a,b,c] = {b=>2,c=>3,a=>1}",
      "[$a, $b] = 1",
      "[$a, $b] = [1,2,3]",
      "[$a, [$b,$c]] = [1,[2]]",
      "[$a, [$b,$c]] = [1,[2,3,4]]",
      "[$a, $b] = {a=>1}",
      "[$a, [$b, $c]] = {a=>1, b =>{b=>2, c=>3}}",
    ].each do |source|
        it "should parse and evaluate the expression '#{source}' to error" do
          expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(Puppet::ParseError)
        end
      end
  end

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
      "unless true {} else {5}"         => 5,
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
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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
      "case 1 {
         Integer : { yes }
         Type[Integer] : { no } }"                           => 'yes',
      "case Integer {
         Integer : { no }
         Type[Integer] : { yes } }"                          => 'yes',
      # supports unfold
      "case ringo {
         *[paul, john, ringo, george] : { 'beatle' } }"      => 'beatle',

      "case ringo {
         (*[paul, john, ringo, george]) : { 'beatle' } }"    => 'beatle',

      "case undef {
         undef : { 'yes' } }"                                => 'yes',

      "case undef {
         *undef : { 'no' }
         default :{ 'yes' }}"                                => 'yes',

      "case [green, 2, whatever] {
         [/ee/, Integer[0,10], default] : { 'yes' }
         default :{ 'no' }}"                                => 'yes',

      "case [green, 2, whatever] {
         default :{ 'no' }
         [/ee/, Integer[0,10], default] : { 'yes' }}"        => 'yes',

      "case {a=>1, b=>2, whatever=>3, extra => ignored} {
         { a => Integer[0,5],
           b => Integer[0,5],
           whatever => default
         }       : { 'yes' }
         default : { 'no' }}"                               => 'yes',

    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

    {
      "2 ? { 1 => no, 2 => yes}"                          => 'yes',
      "3 ? { 1 => no, 2 => no, default => yes }"          => 'yes',
      "3 ? { 1 => no, default => yes, 3 => no }"          => 'no',
      "3 ? { 1 => no, 3 => no, default => yes }"          => 'no',
      "4 ? { 1 => no, default => yes, 3 => no }"          => 'yes',
      "4 ? { 1 => no, 3 => no, default => yes }"          => 'yes',
      "'banana' ? { /.*(ana).*/  => $1 }"                 => 'ana',
      "[2] ? { Array[String] => yes, Array => yes}"       => 'yes',
      "ringo ? *[paul, john, ringo, george] => 'beatle'"  => 'beatle',
      "ringo ? (*[paul, john, ringo, george]) => 'beatle'"=> 'beatle',
      "undef ? undef => 'yes'"                            => 'yes',
      "undef ? {*undef => 'no', default => 'yes'}"        => 'yes',

      "[green, 2, whatever] ? {
         [/ee/, Integer[0,10], default
         ]       => 'yes',
         default => 'no'}"                                => 'yes',

      "{a=>1, b=>2, whatever=>3, extra => ignored} ?
         {{ a => Integer[0,5],
           b => Integer[0,5],
           whatever => default
         }       => 'yes',
         default => 'no' }"                               => 'yes',

    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

    it 'fails if a selector does not match' do
      expect{parser.evaluate_string(scope, "2 ? 3 => 4")}.to raise_error(/No matching entry for selector parameter with value '2'/)
    end
  end

  context "When evaluator evaluated unfold" do
    {
      "*[1,2,3]"             => [1,2,3],
      "*1"                   => [1],
      "*'a'"                 => ['a']
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    it "should parse and evaluate the expression '*{a=>10, b=>20} to [['a',10],['b',20]]" do
      result = parser.evaluate_string(scope, '*{a=>10, b=>20}', __FILE__)
      expect(result).to include(['a', 10])
      expect(result).to include(['b', 20])
    end

    it "should create an array from an Iterator" do
      expect(parser.evaluate_string(scope, '[1,2,3].reverse_each', __FILE__).is_a?(Array)).to be(false)
      result = parser.evaluate_string(scope, '*[1,2,3].reverse_each', __FILE__)
      expect(result).to eql([3,2,1])
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
      "[1,2,3,4][-3,2]"  => [2,3],
      "[1,2,3,4][3,5]"   => [4],
      "[1,2,3,4][5,2]"   => [],
      "[1,2,3,4][0,-1]"  => [1,2,3,4],
      "[1,2,3,4][0,-2]"  => [1,2,3],
      "[1,2,3,4][0,-4]"  => [1],
      "[1,2,3,4][0,-5]"  => [],
      "[1,2,3,4][-5,2]"  => [1],
      "[1,2,3,4][-5,-3]" => [1,2],
      "[1,2,3,4][-6,-3]" => [1,2],
      "[1,2,3,4][2,-3]"  => [],
      "[1,*[2,3],4]"     => [1,2,3,4],
      "[1,*[2,3],4][1]"  => 2,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    {
      "{a=>1, b=>2, c=>3}[a]"                => 1,
      "{a=>1, b=>2, c=>3}[c]"                => 3,
      "{a=>1, b=>2, c=>3}[x]"                => nil,
      "{a=>1, b=>2, c=>3}[c,b]"              => [3,2],
      "{a=>1, b=>2, c=>3}[a,b,c]"            => [1,2,3],
      "{a=>{b=>{c=>'it works'}}}[a][b][c]"   => 'it works',
      "$a = {undef => 10} $a[free_lunch]"     => nil,
      "$a = {undef => 10} $a[undef]"          => 10,
      "$a = {undef => 10} $a[$a[free_lunch]]" => 10,
      "$a = {} $a[free_lunch] == undef"       => true,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    {
      "'abc'[0]"      => 'a',
      "'abc'[2]"      => 'c',
      "'abc'[-1]"     => 'c',
      "'abc'[-2]"     => 'b',
      "'abc'[-3]"     => 'a',
      "'abc'[-4]"     => '',
      "'abc'[3]"      => '',
      "abc[0]"        => 'a',
      "abc[2]"        => 'c',
      "abc[-1]"       => 'c',
      "abc[-2]"       => 'b',
      "abc[-3]"       => 'a',
      "abc[-4]"       => '',
      "abc[3]"        => '',
      "'abcd'[0,2]"   => 'ab',
      "'abcd'[1,3]"   => 'bcd',
      "'abcd'[-2,2]"  => 'cd',
      "'abcd'[-3,2]"  => 'bc',
      "'abcd'[3,5]"   => 'd',
      "'abcd'[5,2]"   => '',
      "'abcd'[0,-1]"  => 'abcd',
      "'abcd'[0,-2]"  => 'abc',
      "'abcd'[0,-4]"  => 'a',
      "'abcd'[0,-5]"  => '',
      "'abcd'[-5,2]"  => 'a',
      "'abcd'[-5,-3]" => 'ab',
      "'abcd'[-6,-3]" => 'ab',
      "'abcd'[2,-3]"  => '',
   }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    # Type operations (full set tested by tests covering type calculator)
    {
      "Array[Integer]"                  => types.array_of(types.integer),
      "Array[Integer,1]"                => types.array_of(types.integer, types.range(1, :default)),
      "Array[Integer,1,2]"              => types.array_of(types.integer, types.range(1, 2)),
      "Array[Integer,Integer[1,2]]"     => types.array_of(types.integer, types.range(1, 2)),
      "Array[Integer,Integer[1]]"       => types.array_of(types.integer, types.range(1, :default)),
      "Hash[Integer,Integer]"           => types.hash_of(types.integer, types.integer),
      "Hash[Integer,Integer,1]"         => types.hash_of(types.integer, types.integer, types.range(1, :default)),
      "Hash[Integer,Integer,1,2]"       => types.hash_of(types.integer, types.integer, types.range(1, 2)),
      "Hash[Integer,Integer,Integer[1,2]]" => types.hash_of(types.integer, types.integer, types.range(1, 2)),
      "Hash[Integer,Integer,Integer[1]]"   => types.hash_of(types.integer, types.integer, types.range(1, :default)),
      "Resource[File]"                  => types.resource('File'),
      "Resource['File']"                => types.resource(types.resource('File')),
      "File[foo]"                       => types.resource('file', 'foo'),
      "File[foo, bar]"                  => [types.resource('file', 'foo'), types.resource('file', 'bar')],
      "Pattern[a, /b/, Pattern[c], Regexp[d]]"  => types.pattern('a', 'b', 'c', 'd'),
      "String[1,2]"                     => types.string(types.range(1, 2)),
      "String[Integer[1,2]]"            => types.string(types.range(1, 2)),
      "String[Integer[1]]"              => types.string(types.range(1, :default)),
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
      end
    end

    # LHS where [] not supported, and missing key(s)
    {
      "Array[]"                    => :error,
      "'abc'[]"                    => :error,
      "Resource[]"                 => :error,
      "File[]"                     => :error,
      "String[]"                   => :error,
      "1[]"                        => :error,
      "3.14[]"                     => :error,
      "/.*/[]"                     => :error,
      "$a=[1] $a[]"                => :error,
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(/Syntax error/)
      end
    end

    # Errors when wrong number/type of keys are used
    {
      "Array[0]"                    => 'Array-Type[] arguments must be types. Got Fixnum',
      "Hash[0]"                     => 'Hash-Type[] arguments must be types. Got Fixnum',
      "Hash[Integer, 0]"            => 'Hash-Type[] arguments must be types. Got Fixnum',
      "Array[Integer,1,2,3]"        => 'Array-Type[] accepts 1 to 3 arguments. Got 4',
      "Array[Integer,String]"       => "A Type's size constraint arguments must be a single Integer type, or 1-2 integers (or default). Got a String-Type",
      "Hash[Integer,String, 1,2,3]" => 'Hash-Type[] accepts 2 to 4 arguments. Got 5',
      "'abc'[x]"                    => "The value 'x' cannot be converted to Numeric",
      "'abc'[1.0]"                  => "A String[] cannot use Float where Integer is expected",
      "'abc'[1,2,3]"                => "String supports [] with one or two arguments. Got 3",
      "NotUndef[0]"                 => 'NotUndef-Type[] argument must be a Type or a String. Got Fixnum',
      "NotUndef[a,b]"               => 'NotUndef-Type[] accepts 0 to 1 arguments. Got 2',
      "Resource[0]"                 => 'First argument to Resource[] must be a resource type or a String. Got Integer',
      "Resource[a, 0]"              => 'Error creating type specialization of a Resource-Type, Cannot use Integer where a resource title String is expected',
      "File[0]"                     => 'Error creating type specialization of a File-Type, Cannot use Integer where a resource title String is expected',
      "String[a]"                   => "A Type's size constraint arguments must be a single Integer type, or 1-2 integers (or default). Got a String",
      "Pattern[0]"                  => 'Error creating type specialization of a Pattern-Type, Cannot use Integer where String or Regexp or Pattern-Type or Regexp-Type is expected',
      "Regexp[0]"                   => 'Error creating type specialization of a Regexp-Type, Cannot use Integer where String or Regexp is expected',
      "Regexp[a,b]"                 => 'A Regexp-Type[] accepts 1 argument. Got 2',
      "true[0]"                     => "Operator '[]' is not applicable to a Boolean",
      "1[0]"                        => "Operator '[]' is not applicable to an Integer",
      "3.14[0]"                     => "Operator '[]' is not applicable to a Float",
      "/.*/[0]"                     => "Operator '[]' is not applicable to a Regexp",
      "[1][a]"                      => "The value 'a' cannot be converted to Numeric",
      "[1][0.0]"                    => "An Array[] cannot use Float where Integer is expected",
      "[1]['0.0']"                  => "An Array[] cannot use Float where Integer is expected",
      "[1,2][1, 0.0]"               => "An Array[] cannot use Float where Integer is expected",
      "[1,2][1.0, -1]"              => "An Array[] cannot use Float where Integer is expected",
      "[1,2][1, -1.0]"              => "An Array[] cannot use Float where Integer is expected",
    }.each do |source, result|
      it "should parse and evaluate the expression '#{source}' to #{result}" do
        expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(Regexp.new(Regexp.quote(result)))
      end
    end

    context "on catalog types" do
      it "[n] gets resource parameter [n]" do
        source = "notify { 'hello': message=>'yo'} Notify[hello][message]"
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq('yo')
      end

      it "[n] gets class parameter [n]" do
        source = "class wonka($produces='chocolate'){ }
           include wonka
           Class[wonka][produces]"

        # This is more complicated since it needs to run like 3.x and do an import_ast
        adapted_parser = Puppet::Parser::E4ParserAdapter.new
        adapted_parser.file = __FILE__
        ast = adapted_parser.parse(source)
        Puppet.override({:global_scope => scope,
                         :environments => Puppet::Environments::Static.new(@node.environment)
        }, "gets class parameter test") do
          scope.known_resource_types.import_ast(ast, '')
          expect(ast.code.safeevaluate(scope)).to eq('chocolate')
        end
      end

      # Resource default and override expressions and resource parameter access with []
      {
        # Properties
        "notify { id: message=>explicit} Notify[id][message]"                   => "explicit",
        "Notify { message=>by_default} notify {foo:} Notify[foo][message]"      => "by_default",
        "notify {foo:} Notify[foo]{message =>by_override} Notify[foo][message]" => "by_override",
        # Parameters
        "notify { id: withpath=>explicit} Notify[id][withpath]"                 => "explicit",
        "Notify { withpath=>by_default } notify { foo: } Notify[foo][withpath]" => "by_default",
        "notify {foo:}
         Notify[foo]{withpath=>by_override}
         Notify[foo][withpath]"                                                 => "by_override",
        # Metaparameters
        "notify { foo: tag => evoe} Notify[foo][tag]"                           => "evoe",
        # Does not produce the defaults for tag parameter (title, type or names of scopes)
        "notify { foo: } Notify[foo][tag]"                                      => nil,
        # But a default may be specified on the type
        "Notify { tag=>by_default } notify { foo: } Notify[foo][tag]"           => "by_default",
        "Notify { tag=>by_default }
         notify { foo: }
         Notify[foo]{ tag=>by_override }
         Notify[foo][tag]"                                                      => "by_override",
      }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

      # Virtual and realized resource default and overridden resource parameter access with []
      {
        # Properties
        "@notify { id: message=>explicit } Notify[id][message]"                 => "explicit",
        "@notify { id: message=>explicit }
         realize Notify[id]
         Notify[id][message]"                                                   => "explicit",
        "Notify { message=>by_default } @notify { id: } Notify[id][message]"    => "by_default",
        "Notify { message=>by_default }
         @notify { id: tag=>thisone }
         Notify <| tag == thisone |>;
         Notify[id][message]"                                                   => "by_default",
        "@notify { id: } Notify[id]{message=>by_override} Notify[id][message]"  => "by_override",
        # Parameters
        "@notify { id: withpath=>explicit } Notify[id][withpath]"               => "explicit",
        "Notify { withpath=>by_default }
         @notify { id: }
         Notify[id][withpath]"                                                  => "by_default",
        "@notify { id: }
         realize Notify[id]
         Notify[id]{withpath=>by_override}
         Notify[id][withpath]"                                                  => "by_override",
        # Metaparameters
        "@notify { id: tag=>explicit } Notify[id][tag]"                         => "explicit",
      }.each do |source, result|
        it "parses and evaluates virtual and realized resources in the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

      # Exported resource attributes
      {
        "@@notify { id: message=>explicit } Notify[id][message]"                => "explicit",
        "@@notify { id: message=>explicit, tag=>thisone }
         Notify <<| tag == thisone |>>
         Notify[id][message]"                                                   => "explicit",
      }.each do |source, result|
        it "parses and evaluates exported resources in the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

      # Resource default and override expressions and resource parameter access error conditions
      {
        "notify { xid: message=>explicit} Notify[id][message]"  => /Resource not found/,
        "notify { id: message=>explicit} Notify[id][mustard]"   => /does not have a parameter called 'mustard'/,
        # NOTE: these meta-esque parameters are not recognized as such
        "notify { id: message=>explicit} Notify[id][title]"   => /does not have a parameter called 'title'/,
        "notify { id: message=>explicit} Notify[id]['type']"   => /does not have a parameter called 'type'/,
        "notify { id: message=>explicit } Notify[id]{message=>override}" => /'message' is already set on Notify\[id\]/,
        "notify { id: message => 'once', message => 'twice' }" => /'message' has already been set/
      }.each do |source, result|
        it "should parse '#{source}' and raise error matching #{result}" do
          expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(result)
        end
      end

      context 'with errors' do
        { "Class['fail-whale']" => /Illegal name/,
          "Class[0]"            => /An Integer cannot be used where a String is expected/,
          "Class[/.*/]"         => /A Regexp cannot be used where a String is expected/,
          "Class[4.1415]"       => /A Float cannot be used where a String is expected/,
          "Class[Integer]"      => /An Integer-Type cannot be used where a String is expected/,
          "Class[File['tmp']]"   => /A File\['tmp'\] Resource-Reference cannot be used where a String is expected/,
        }.each do | source, error_pattern|
          it "an error is flagged for '#{source}'" do
            expect { parser.evaluate_string(scope, source, __FILE__)}.to raise_error(error_pattern)
          end
        end
      end
    end
  # end [] operations
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
      "! ''"            => false,
      "! undef"         => true,
      "! [a]"           => false,
      "! []"            => false,
      "! {a=>1}"        => false,
      "! {}"            => false,
      "true and false and '0xwtf' + 1"  => false,
      "false or true  or '0xwtf' + 1"  => true,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
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

  context "When evaluator performs operations on literal undef" do
    it "computes non existing hash lookup as undef" do
      expect(parser.evaluate_string(scope, "{a => 1}[b] == undef", __FILE__)).to eq(true)
      expect(parser.evaluate_string(scope, "undef == {a => 1}[b]", __FILE__)).to eq(true)
    end
  end

  context "When evaluator performs calls" do

    let(:populate) do
      parser.evaluate_string(scope, "$a = 10 $b = [1,2,3]")
    end

    {
      'sprintf( "x%iy", $a )'                 => "x10y",
      # unfolds
      'sprintf( *["x%iy", $a] )'              => "x10y",
      '( *["x%iy", $a] ).sprintf'             => "x10y",
      '((*["x%iy", $a])).sprintf'             => "x10y",
      '"x%iy".sprintf( $a )'                  => "x10y",
      '$b.reduce |$memo,$x| { $memo + $x }'   => 6,
      'reduce($b) |$memo,$x| { $memo + $x }'  => 6,
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    it "provides location information on error in unparenthesized call logic" do
    expect{parser.evaluate_string(scope, "include non_existing_class", __FILE__)}.to raise_error(Puppet::ParseError, /:1:1/)
    end

    it 'defaults can be given in a lambda and used only when arg is missing' do
      env_loader = @compiler.loaders.public_environment_loader
      fc = Puppet::Functions.create_function(:test) do
        dispatch :test do
          param 'Integer', :count
          required_block_param
        end
        def test(count)
          yield(*[].fill(10, 0, count))
        end
      end
      the_func = fc.new({}, env_loader)
      env_loader.add_entry(:function, 'test', the_func, __FILE__)
      expect(parser.evaluate_string(scope, "test(1) |$x, $y=20| { $x + $y}")).to eql(30)
      expect(parser.evaluate_string(scope, "test(2) |$x, $y=20| { $x + $y}")).to eql(20)
    end

    it 'a given undef does not select the default value' do
      env_loader = @compiler.loaders.public_environment_loader
      fc = Puppet::Functions.create_function(:test) do
        dispatch :test do
          param 'Any', :lambda_arg
          required_block_param
        end
        def test(lambda_arg)
          yield(lambda_arg)
        end
      end
      the_func = fc.new({}, env_loader)
      env_loader.add_entry(:function, 'test', the_func, __FILE__)

      expect(parser.evaluate_string(scope, "test(undef) |$x=20| { $x == undef}")).to eql(true)
    end

    it 'a given undef is given as nil' do
      env_loader = @compiler.loaders.public_environment_loader
      fc = Puppet::Functions.create_function(:assert_no_undef) do
        dispatch :assert_no_undef do
          param 'Any', :x
        end

        def assert_no_undef(x)
          case x
          when Array
            return unless x.include?(:undef)
          when Hash
            return unless x.keys.include?(:undef) || x.values.include?(:undef)
          else
            return unless x == :undef
          end
          raise "contains :undef"
        end
      end

      the_func = fc.new({}, env_loader)
      env_loader.add_entry(:function, 'assert_no_undef', the_func, __FILE__)

      expect{parser.evaluate_string(scope, "assert_no_undef(undef)")}.to_not raise_error()
      expect{parser.evaluate_string(scope, "assert_no_undef([undef])")}.to_not raise_error()
      expect{parser.evaluate_string(scope, "assert_no_undef({undef => 1})")}.to_not raise_error()
      expect{parser.evaluate_string(scope, "assert_no_undef({1 => undef})")}.to_not raise_error()
    end

    context 'using the 3x function api' do
      it 'can call a 3x function' do
        Puppet::Parser::Functions.newfunction("bazinga", :type => :rvalue) { |args| args[0] }
        expect(parser.evaluate_string(scope, "bazinga(42)", __FILE__)).to eq(42)
      end

      it 'maps :undef to empty string' do
        Puppet::Parser::Functions.newfunction("bazinga", :type => :rvalue) { |args| args[0] }
        expect(parser.evaluate_string(scope, "$a = {} bazinga($a[nope])", __FILE__)).to eq('')
        expect(parser.evaluate_string(scope, "bazinga(undef)", __FILE__)).to eq('')
      end

      it 'does not map :undef to empty string in arrays' do
        Puppet::Parser::Functions.newfunction("bazinga", :type => :rvalue) { |args| args[0][0] }
        expect(parser.evaluate_string(scope, "$a = {} $b = [$a[nope]] bazinga($b)", __FILE__)).to eq(:undef)
        expect(parser.evaluate_string(scope, "bazinga([undef])", __FILE__)).to eq(:undef)
      end

      it 'does not map :undef to empty string in hashes' do
        Puppet::Parser::Functions.newfunction("bazinga", :type => :rvalue) { |args| args[0]['a'] }
        expect(parser.evaluate_string(scope, "$a = {} $b = {a => $a[nope]} bazinga($b)", __FILE__)).to eq(:undef)
        expect(parser.evaluate_string(scope, "bazinga({a => undef})", __FILE__)).to eq(:undef)
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
      '"value is ${/.*/} yo"'                 => "value is /.*/ yo",
      '$x = undef "value is $x yo"'           => "value is  yo",
      '$x = default "value is $x yo"'         => "value is default yo",
      '$x = Array[Integer] "value is $x yo"'  => "value is Array[Integer] yo",
      '"value is ${Array[Integer]} yo"'       => "value is Array[Integer] yo",
    }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          populate
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(result)
        end
      end

    it "should parse and evaluate an interpolation of a hash" do
      source = '"value is ${{a=>1,b=>2}} yo"'
      # This test requires testing against two options because a hash to string
      # produces a result that is unordered
      hashstr = {'a' => 1, 'b' => 2}.to_s
      alt_results = ["value is {a => 1, b => 2} yo", "value is {b => 2, a => 1} yo" ]
      populate
      parse_result = parser.evaluate_string(scope, source, __FILE__)
      expect(alt_results.include?(parse_result)).to eq(true)
    end

    it 'should accept a variable with leading underscore when used directly' do
      source = '$_x = 10; "$_x"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('10')
    end

    it 'should accept a variable with leading underscore when used as an expression' do
      source = '$_x = 10; "${_x}"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('10')
    end

    it 'should accept a numeric variable expressed as $n' do
      source = '$x = "abc123def" =~ /(abc)(123)(def)/; "${$2}"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('123')
    end

    it 'should accept a numeric variable expressed as just an integer' do
      source = '$x = "abc123def" =~ /(abc)(123)(def)/; "${2}"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('123')
    end

    it 'should accept a numeric variable expressed as $n in an access operation' do
      source = '$x = "abc123def" =~ /(abc)(123)(def)/; "${$0[4,3]}"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('23d')
    end

    it 'should accept a numeric variable expressed as just an integer in an access operation' do
      source = '$x = "abc123def" =~ /(abc)(123)(def)/; "${0[4,3]}"'
      expect(parser.evaluate_string(scope, source, __FILE__)).to eql('23d')
    end

    {
      '"value is ${a*2} yo"'  => :error,
    }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end
  end

  context "When evaluating variables" do
    context "that are non existing an error is raised for" do
      it "unqualified variable" do
        expect { parser.evaluate_string(scope, "$quantum_gravity", __FILE__) }.to raise_error(/Unknown variable/)
      end

      it "qualified variable" do
        expect { parser.evaluate_string(scope, "$quantum_gravity::graviton", __FILE__) }.to raise_error(/Unknown variable/)
      end
    end

    it "a lex error should be raised for '$foo::::bar'" do
      expect { parser.evaluate_string(scope, "$foo::::bar") }.to raise_error(Puppet::ParseErrorWithIssue, /Illegal fully qualified name at line 1:7/)
    end

    { '$a = $0'   => nil,
      '$a = $1'   => nil,
    }.each do |source, value|
      it "it is ok to reference numeric unassigned variables '#{source}'" do
        expect(parser.evaluate_string(scope, source, __FILE__)).to eq(value)
      end
    end

    { '$00 = 0'   => /must be a decimal value/,
      '$0xf = 0'  => /must be a decimal value/,
      '$0777 = 0' => /must be a decimal value/,
      '$123a = 0' => /must be a decimal value/,
    }.each do |source, error_pattern|
      it "should raise an error for '#{source}'" do
        expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(error_pattern)
      end
    end

    context "an initial underscore in the last segment of a var name is allowed" do
      { '$_a  = 1'   => 1,
        '$__a = 1'   => 1,
      }.each do |source, value|
        it "as in this example '#{source}'" do
          expect(parser.evaluate_string(scope, source, __FILE__)).to eq(value)
        end
      end
    end
  end

  context "When evaluating relationships" do
    it 'should form a relation with File[a] -> File[b]' do
      source = "File[a] -> File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['File', 'a', '->', 'File', 'b'])
    end

    it 'should form a relation with resource -> resource' do
      source = "notify{a:} -> notify{b:}"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['Notify', 'a', '->', 'Notify', 'b'])
    end

    it 'should form a relation with [File[a], File[b]] -> [File[x], File[y]]' do
      source = "[File[a], File[b]] -> [File[x], File[y]]"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['File', 'a', '->', 'File', 'x'])
      expect(scope.compiler).to have_relationship(['File', 'b', '->', 'File', 'x'])
      expect(scope.compiler).to have_relationship(['File', 'a', '->', 'File', 'y'])
      expect(scope.compiler).to have_relationship(['File', 'b', '->', 'File', 'y'])
    end

    it 'should form a relation with 3.x resource -> resource' do
      # Create a 3.x resource since this is the value given as arguments to defined type
      scope['a_3x_resource']= Puppet::Parser::Resource.new('notify', 'a', {:scope => scope, :file => __FILE__, :line => 1})
      source = "$a_3x_resource -> notify{b:}"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['Notify', 'a', '->', 'Notify', 'b'])
    end

    it 'should tolerate (eliminate) duplicates in operands' do
      source = "[File[a], File[a]] -> File[x]"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['File', 'a', '->', 'File', 'x'])
      expect(scope.compiler.relationships.size).to eq(1)
    end

    it 'should form a relation with <-' do
      source = "File[a] <- File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['File', 'b', '->', 'File', 'a'])
    end

    it 'should form a relation with <-' do
      source = "File[a] <~ File[b]"
      parser.evaluate_string(scope, source, __FILE__)
      expect(scope.compiler).to have_relationship(['File', 'b', '~>', 'File', 'a'])
    end
  end

  context "When evaluating heredoc" do
    it "evaluates plain heredoc" do
      src = "@(END)\nThis is\nheredoc text\nEND\n"
      expect(parser.evaluate_string(scope, src)).to eq("This is\nheredoc text\n")
    end

    it "parses heredoc with margin" do
      src = [
      "@(END)",
      "   This is",
      "   heredoc text",
      "   | END",
      ""
      ].join("\n")
      expect(parser.evaluate_string(scope, src)).to eq("This is\nheredoc text\n")
    end

    it "parses heredoc with margin and right newline trim" do
      src = [
      "@(END)",
      "   This is",
      "   heredoc text",
      "   |- END",
      ""
      ].join("\n")
      expect(parser.evaluate_string(scope, src)).to eq("This is\nheredoc text")
    end

    it "parses escape specification" do
      src = <<-CODE
      @(END/t)
      Tex\\tt\\n
      |- END
      CODE
      expect(parser.evaluate_string(scope, src)).to eq("Tex\tt\\n")
    end

    it "parses syntax checked specification" do
      src = <<-CODE
      @(END:json)
      ["foo", "bar"]
      |- END
      CODE
      expect(parser.evaluate_string(scope, src)).to eq('["foo", "bar"]')
    end

    it "parses syntax checked specification with error and reports it" do
      src = <<-CODE
      @(END:json)
      ['foo', "bar"]
      |- END
      CODE
      expect { parser.evaluate_string(scope, src)}.to raise_error(/Cannot parse invalid JSON string/)
    end

    it "parses interpolated heredoc expression" do
      src = <<-CODE
      $pname = 'Fjodor'
      @("END")
      Hello $pname
      |- END
      CODE
      expect(parser.evaluate_string(scope, src)).to eq("Hello Fjodor")
    end

    it "parses interpolated heredoc expression with escapes" do
      src = <<-CODE
      $name = 'Fjodor'
      @("END")
      Hello\\ \\$name
      |- END
      CODE
      expect(parser.evaluate_string(scope, src)).to eq("Hello\\ \\Fjodor")
    end

  end
  context "Handles Deprecations and Discontinuations" do
    it 'of import statements' do
      source = "\nimport foo"
      # Error references position 5 at the opening '{'
      # Set file to nil to make it easier to match with line number (no file name in output)
      expect { parser.evaluate_string(scope, source) }.to raise_error(/'import' has been discontinued.*line 2:1/)
    end
  end

  context "Detailed Error messages are reported" do
    it 'for illegal type references' do
      source = '1+1 { "title": }'
      # Error references position 5 at the opening '{'
      # Set file to nil to make it easier to match with line number (no file name in output)
      expect { parser.evaluate_string(scope, source) }.to raise_error(
        /Illegal Resource Type expression, expected result to be a type name, or untitled Resource.*line 1:2/)
    end

    it 'for non r-value producing <| |>' do
      expect { parser.parse_string("$a = File <| |>", nil) }.to raise_error(/A Virtual Query does not produce a value at line 1:6/)
    end

    it 'for non r-value producing <<| |>>' do
      expect { parser.parse_string("$a = File <<| |>>", nil) }.to raise_error(/An Exported Query does not produce a value at line 1:6/)
    end

    it 'for non r-value producing define' do
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => "Invalid use of expression. A 'define' expression does not produce a value", :line => 1, :pos => 6))
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => 'Classes, definitions, and nodes may only appear at toplevel or inside other classes', :line => 1, :pos => 6))
      expect { parser.parse_string("$a = define foo { }", nil) }.to raise_error(/2 errors/)
    end

    it 'for non r-value producing class' do
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => 'Invalid use of expression. A Host Class Definition does not produce a value', :line => 1, :pos => 6))
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => 'Classes, definitions, and nodes may only appear at toplevel or inside other classes', :line => 1, :pos => 6))
      expect { parser.parse_string("$a = class foo { }", nil) }.to raise_error(/2 errors/)
    end

    it 'for unclosed quote with indication of start position of string' do
      source = <<-SOURCE.gsub(/^ {6}/,'')
      $a = "xx
      yyy
      SOURCE
      # first char after opening " reported as being in error.
      expect { parser.parse_string(source) }.to raise_error(/Unclosed quote after '"' followed by 'xx\\nyy\.\.\.' at line 1:7/)
    end

    it 'for multiple errors with a summary exception' do
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => 'Invalid use of expression. A Node Definition does not produce a value', :line => 1, :pos => 6))
      Puppet::Util::Log.expects(:create).with(has_entries(:level => :err, :message => 'Classes, definitions, and nodes may only appear at toplevel or inside other classes', :line => 1, :pos => 6))
      expect { parser.parse_string("$a = node x { }",nil) }.to raise_error(/2 errors/)
    end

    it 'for a bad hostname' do
      expect {
        parser.parse_string("node 'macbook+owned+by+name' { }", nil)
      }.to raise_error(/The hostname 'macbook\+owned\+by\+name' contains illegal characters.*at line 1:6/)
    end

    it 'for a hostname with interpolation' do
      source = <<-SOURCE.gsub(/^ {6}/,'')
      $pname = 'fred'
      node "macbook-owned-by$pname" { }
      SOURCE
      expect {
        parser.parse_string(source, nil)
      }.to raise_error(/An interpolated expression is not allowed in a hostname of a node at line 2:23/)
    end

  end

  context 'does not leak variables' do
    it 'local variables are gone when lambda ends' do
      source = <<-SOURCE
      [1,2,3].each |$x| { $y = $x}
      $a = $y
      SOURCE
      expect do
        parser.evaluate_string(scope, source)
      end.to raise_error(/Unknown variable: 'y'/)
    end

    it 'lambda parameters are gone when lambda ends' do
      source = <<-SOURCE
      [1,2,3].each |$x| { $y = $x}
      $a = $x
      SOURCE
      expect do
        parser.evaluate_string(scope, source)
      end.to raise_error(/Unknown variable: 'x'/)
    end

    it 'does not leak match variables' do
      source = <<-SOURCE
      if 'xyz' =~ /(x)(y)(z)/ { notice $2 }
      case 'abc' {
        /(a)(b)(c)/ : { $x = $2 }
      }
      "-$x-$2-"
      SOURCE
      expect(parser.evaluate_string(scope, source)).to eq('-b--')
    end
  end

  matcher :have_relationship do |expected|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |compiler|
      op_name = {'->' => :relationship, '~>' => :subscription}
      compiler.relationships.any? do | relation |
        relation.source.type == expected[0] &&
        relation.source.title == expected[1] &&
        relation.type == op_name[expected[2]] &&
        relation.target.type == expected[3] &&
        relation.target.title == expected[4]
      end
    end

    failure_message do |actual|
      "Relationship #{expected[0]}[#{expected[1]}] #{expected[2]} #{expected[3]}[#{expected[4]}] but was unknown to compiler"
    end
  end

end
