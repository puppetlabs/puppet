#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe Puppet::Pops::Impl::EvaluatorImpl do
  include EvaluatorRspecHelper

  context "When the evaluator performs arithmetic" do
    
    context "on Integers" do
      it "2 + 2  ==  4"   do; evaluate(literal(2) + literal(2)).should == 4 ; end  
      it "7 - 3  ==  4"   do; evaluate(literal(7) - literal(3)).should == 4 ; end
      it "6 * 3  ==  18"  do; evaluate(literal(6) * literal(3)).should == 18; end
      it "6 / 3  ==  2"   do; evaluate(literal(6) / literal(3)).should == 2 ; end
      it "6 % 3  ==  0"   do; evaluate(literal(6) % literal(3)).should == 0 ; end
      it "10 % 3 ==  1"   do; evaluate(literal(10) % literal(3)).should == 1; end
      it "-(6/3) == -2"   do; evaluate(minus(literal(6) / literal(3))).should == -2 ; end
      it "-6/3   == -2"   do; evaluate(minus(literal(6)) / literal(3)).should == -2 ; end
      it "8 >> 1 == 4"    do; evaluate(literal(8) >> literal(1)).should == 4 ; end
      it "8 << 1 == 16"   do; evaluate(literal(8) << literal(1)).should == 16; end
    end
    
    context "on Floats" do
      it "2.2 + 2.2  ==  4.4"   do; evaluate(literal(2.2) + literal(2.2)).should == 4.4  ; end
      it "7.7 - 3.3  ==  4.4"   do; evaluate(literal(7.7) - literal(3.3)).should == 4.4  ; end
      it "6.1 * 3.1  ==  18.91" do; evaluate(literal(6.1) * literal(3.1)).should == 18.91; end
      it "6.6 / 3.3  ==  2.0"   do; evaluate(literal(6.6) / literal(3.3)).should == 2.0  ; end
      it "6.6 % 3.3  ==  0.0"   do; evaluate(literal(6.6) % literal(3.3)).should == 0.0  ; end
      it "10.0 % 3.0 ==  1.0"   do; evaluate(literal(10.0) % literal(3.0)).should == 1.0 ; end
      it "-(6.0/3.0) == -2.0"   do; evaluate(minus(literal(6.0) / literal(3.0))).should == -2.0; end
      it "-6.0/3.0   == -2.0"   do; evaluate(minus(literal(6.0)) / literal(3.0)).should == -2.0; end
      it "3.14 << 2  == error"  do; expect { evaluate(literal(3.14) << literal(2))}.to raise_error(Puppet::Pops::API::EvaluationError); end
      it "3.14 >> 2  == error"  do; expect { evaluate(literal(3.14) >> literal(2))}.to raise_error(Puppet::Pops::API::EvaluationError); end
    end
    
    context "on strings requiring boxing to Numeric" do
      it "'2' + '2'        ==  4" do
        evaluate(literal('2') + literal('2')).should == 4
      end
      
      it "'2.2' + '2.2'    ==  4.4" do
        evaluate(literal('2.2') + literal('2.2')).should == 4.4
      end

      it "'0xF7' + '0x8'   ==  0xFF" do
        evaluate(literal('0xF7') + literal('0x8')).should == 0xFF
      end
      
      it "'0367' + '010'   ==  0xFF" do
        evaluate(literal('0367') + literal('010')).should == 0xFF
      end

      it "'0888' + '010'   ==  error" do
        expect { evaluate(literal('0888') + literal('010'))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end
      
      it "'0xWTF' + '010'  ==  error" do
        expect { evaluate(literal('0xWTF') + literal('010'))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end

      it "'0x12.3' + '010' ==  error" do
        expect { evaluate(literal('0x12.3') + literal('010'))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end

      it "'012.3' + '0.3'  ==  12.6 (not error, floats can start with 0)" do
        evaluate(literal('012.3') + literal('010')) == 12.6
      end
    
    end
  end
  
  context "When the evaluator performs boolean operations" do
    context "using operator AND" do
      it "true  && true  == true" do
        evaluate(literal(true).and(literal(true))).should == true
      end
      it "false && true  == false" do
        evaluate(literal(false).and(literal(true))).should == false
      end
      it "true  && false == false" do
        evaluate(literal(true).and(literal(false))).should == false
      end
      it "false && false == false" do
        evaluate(literal(false).and(literal(false))).should == false
      end
    end
    
    context "using operator OR" do
      it "true  || true  == true" do
        evaluate(literal(true).or(literal(true))).should == true
      end
      it "false || true  == true" do
        evaluate(literal(false).or(literal(true))).should == true
      end
      it "true  || false == true" do
        evaluate(literal(true).or(literal(false))).should == true
      end
      it "false || false == false" do
        evaluate(literal(false).or(literal(false))).should == false
      end
    end
    
    context "using operator NOT" do
      it "!false         == true" do
        evaluate(literal(false).not()).should == true
      end
      it "!true          == false" do
        evaluate(literal(true).not()).should == false
      end
    end
   
    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        evaluate(literal('x').not()).should == false
      end
      it "''             == false" do
        evaluate(literal('').not()).should == true
      end
      it ":undef         == false" do
        evaluate(literal(:undef).not()).should == true
      end
    end
    
    context "connectives should stop when truth is obtained" do
      it "true && false && error  == false (and no failure)" do
        evaluate(literal(false).and(literal('0xwtf') + literal(1)).and(literal(true))).should == false
      end
      it "false || true || error  == true (and no failure)" do
        evaluate(literal(true).or(literal('0xwtf') + literal(1)).or(literal(false))).should == true
      end
      it "false || false || error == error (false positive test)" do
        expect {evaluate(literal(true).and(literal('0xwtf') + literal(1)).or(literal(false)))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end
    end
  end
  context "When the evaluator performs comparisons" do
    context "of string values" do
      it "'a' == 'a' == true"  do; evaluate(literal('a') == literal('a')).should == true   ; end 
      it "'a' == 'b' == false" do; evaluate(literal('a') == literal('b')).should == false  ; end 
      it "'a' != 'a' == false" do; evaluate(literal('a').ne(literal('a'))).should == false ; end 
      it "'a' != 'b' == true"  do; evaluate(literal('a').ne(literal('b'))).should == true  ; end 
      
      it "'a' < 'b'  == true"  do; evaluate(literal('a')  < literal('b')).should == true   ; end 
      it "'a' < 'a'  == false" do; evaluate(literal('a')  < literal('a')).should == false  ; end 
      it "'b' < 'a'  == false" do; evaluate(literal('b')  < literal('a')).should == false  ; end

      it "'a' <= 'b' == true"  do; evaluate(literal('a')  <= literal('b')).should == true  ; end 
      it "'a' <= 'a' == true"  do; evaluate(literal('a')  <= literal('a')).should == true  ; end 
      it "'b' <= 'a' == false" do; evaluate(literal('b')  <= literal('a')).should == false ; end

      it "'a' > 'b'  == false" do; evaluate(literal('a')  > literal('b')).should == false  ; end 
      it "'a' > 'a'  == false" do; evaluate(literal('a')  > literal('a')).should == false  ; end 
      it "'b' > 'a'  == true"  do; evaluate(literal('b')  > literal('a')).should == true   ; end

      it "'a' >= 'b' == false" do; evaluate(literal('a')  >= literal('b')).should == false ; end 
      it "'a' >= 'a' == true"  do; evaluate(literal('a')  >= literal('a')).should == true  ; end 
      it "'b' >= 'a' == true"  do; evaluate(literal('b')  >= literal('a')).should == true  ; end
      context "with mixed case" do
        it "'a' == 'A' == true"    do; evaluate(literal('a') == literal('A')).should == true   ; end 
        it "'a' != 'A' == false"   do; evaluate(literal('a').ne(literal('A'))).should == false ; end 
        it "'a' >  'A' == false"   do; evaluate(literal('a') > literal('A')).should == false   ; end 
        it "'a' >= 'A' == true"    do; evaluate(literal('a') >= literal('A')).should == true   ; end 
        it "'A' <  'a' == false"   do; evaluate(literal('A') < literal('a')).should == false   ; end 
        it "'A' <= 'a' == true"    do; evaluate(literal('A') <= literal('a')).should == true  ; end 
      end
    end
    context "of integer values" do
      it "1 == 1 == true"  do; evaluate(literal(1) == literal(1)).should == true   ; end 
      it "1 == 2 == false" do; evaluate(literal(1) == literal(2)).should == false  ; end 
      it "1 != 1 == false" do; evaluate(literal(1).ne(literal(1))).should == false ; end 
      it "1 != 2 == true"  do; evaluate(literal(1).ne(literal(2))).should == true  ; end 
      
      it "1 < 2  == true"  do; evaluate(literal(1)  < literal(2)).should == true   ; end 
      it "1 < 1  == false" do; evaluate(literal(1)  < literal(1)).should == false  ; end 
      it "2 < 1  == false" do; evaluate(literal(2)  < literal(1)).should == false  ; end

      it "1 <= 2 == true"  do; evaluate(literal(1)  <= literal(2)).should == true  ; end 
      it "1 <= 1 == true"  do; evaluate(literal(1)  <= literal(1)).should == true  ; end 
      it "2 <= 1 == false" do; evaluate(literal(2)  <= literal(1)).should == false ; end

      it "1 > 2  == false" do; evaluate(literal(1)  > literal(2)).should == false  ; end 
      it "1 > 1  == false" do; evaluate(literal(1)  > literal(1)).should == false  ; end 
      it "2 > 1  == true"  do; evaluate(literal(2)  > literal(1)).should == true   ; end

      it "1 >= 2 == false" do; evaluate(literal(1)  >= literal(2)).should == false ; end 
      it "1 >= 1 == true"  do; evaluate(literal(1)  >= literal(1)).should == true  ; end 
      it "2 >= 1 == true"  do; evaluate(literal(2)  >= literal(1)).should == true  ; end      
    end
    context "of mixed value types" do
      it "1 == 1.0  == true"   do; evaluate(literal(1)     == literal(1.0)).should == true   ; end 
      it "1 < 1.1   == true"   do; evaluate(literal(1)     <  literal(1.1)).should == true   ; end 
      it "'1' < 1.1 == true"   do; evaluate(literal('1')   <  literal(1.1)).should == true   ; end 
      it "1.0 == 1  == true"   do; evaluate(literal(1.0)   == literal(1)).should == true     ; end 
      it "1.0 < 2   == true"   do; evaluate(literal(1.0)   <  literal(2)).should == true     ; end 
      it "'1.0' < 1.1 == true" do; evaluate(literal('1.0') <  literal(1.1)).should == true   ; end

      it "'1.0' < 'a' == true" do; evaluate(literal('1.0') <  literal('a')).should == true   ; end
      it "'1.0' < ''  == true" do; evaluate(literal('1.0') <  literal('')).should == true    ; end
      it "'1.0' < ' ' == true" do; evaluate(literal('1.0') <  literal(' ')).should == true   ; end
      it "'a' > '1.0' == true" do; evaluate(literal('a')   >  literal('1.0')).should == true ; end
    end
    context "of regular expressions" do
      it "/.*/ == /.*/  == true"   do; evaluate(literal(/.*/) == literal(/.*/)).should == true   ; end 
      it "/.*/ != /a.*/ == true"   do; evaluate(literal(/.*/).ne(literal(/a.*/))).should == true ; end 
    end
    context "of booleans" do
      it "true  == true  == true"  do; evaluate(literal(true) == literal(true)).should == true  ; end;
      it "false == false == true" do; evaluate(literal(false) == literal(false)).should == true ; end;
      it "true == false  != true" do; evaluate(literal(true) == literal(false)).should == false ; end;
    end
    context "of non comparable types" do
      it "false < true  == error" do
        expect { evaluate(literal(true) < literal(false))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end
      it "/a/ < /b/     == error" do
        expect { evaluate(literal(/a/) < literal(/b/))}.to raise_error(Puppet::Pops::API::EvaluationError)
      end
    end
  end
  context "When the evaluator performs Regular Expression matching" do
    it "'a' =~ /.*/   == true"    do; evaluate(literal('a') =~ literal(/.*/)).should == true     ; end
    it "'a' =~ '.*'   == true"    do; evaluate(literal('a') =~ literal(".*")).should == true     ; end
    it "'a' !~ /b.*/  == true"    do; evaluate(literal('a').mne(literal(/b.*/))).should == true  ; end
    it "'a' !~ 'b.*'  == true"    do; evaluate(literal('a').mne(literal("b.*"))).should == true  ; end
  end
  context "When the evaluator evaluates Lists" do
    it "should create an Array when evaluating a LiteralList" do
      evaluate(literal([1,2,3])).should == [1,2,3]
    end
    it "[...[...[]]] should create nested arrays without trouble" do
      evaluate(literal([1,[2.0, 2.1, [2.2]],[3.0, 3.1]])).should == [1,[2.0, 2.1, [2.2]],[3.0, 3.1]]
    end
    it "[2 + 2] should evaluate expressions in entries" do
      x = literal([literal(2) + literal(2)]);
      Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x).should == "([] (+ 2 2))"
      evaluate(x)[0].should == 4
    end
    it "[1,2,3] == [1,2,3] == true" do
      evaluate(literal([1,2,3]) == literal([1,2,3])).should == true;
    end
    it "[1,2,3] != [2,3,4] == true" do
      evaluate(literal([1,2,3]).ne(literal([2,3,4]))).should == true;
    end
    it "[1, 2, 3][2] == 3" do
      evaluate(literal([1,2,3])[2]).should == 3
    end
  end
  context "When the evaluator evaluates Hashes" do
    it "should create a  Hash when evaluating a LiteralHash" do
      evaluate(literal({'a'=>1,'b'=>2})).should == {'a'=>1,'b'=>2}
    end
    it "{...{...{}}} should create nested hashes without trouble" do
      evaluate(literal({'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}})).should == {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}
    end
    it "{'a'=> 2 + 2} should evaluate values in entries" do
      evaluate(literal({'a'=> literal(2) + literal(2)}))['a'].should == 4
    end
    it "{'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2} == true" do
      evaluate(literal({'a'=> 1, 'b'=>2}) == literal({'a'=> 1, 'b'=>2})).should == true;
    end
    it "{'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3} == true" do
      evaluate(literal({'a'=> 1, 'b'=>2}).ne(literal({'x'=> 1, 'y'=>3}))).should == true;
    end
    it "{'a' => 1, 'b' => 2}['b'] == 2" do
      evaluate(literal({:a => 1, :b => 2})[:b]).should == 2
    end
  end
  context "When evaluator evaluates the 'in' operator" do
    it "should find elements in an array" do
      evaluate(literal(1).in(literal([1,2,3]))).should == true
    end
    it "should find keys in a hash" do
      evaluate(literal('a').in(literal({'x'=>1, 'a'=>2, 'y'=> 3}))).should == true
    end
    it "should find substrings in a string" do
      evaluate(literal('ana').in(literal('bananas'))).should == true
    end
    it "should find sublists in a list" do
      evaluate(literal([2,3]).in(literal([1,[2,3],4]))).should == true
    end
    it "should find numbers as numbers" do
      evaluate(literal(15).in(literal([1,0xf,2]))).should == true
    end
    it "should not find numbers as strings" do
      evaluate(literal(15).in(literal([1, '0xf',2]))).should == false
      evaluate(literal('15').in(literal([1, 0xf,2]))).should == false
    end
  end
  context "When evaluator performs string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      a_block = block(fqn('a').set(10), string('value is ', text(fqn('a')), ' yo'))
      evaluate(a_block).should == "value is 10 yo"
    end
    it "should interpolate a variable in a text expression, \"${$var}\"" do
      a_block = block(fqn('a').set(10), string('value is ', text(var(fqn('a'))), ' yo'))
      evaluate(a_block).should == "value is 10 yo"
    end
    it "should interpolate a variable, \"$var\"" do
      a_block = block(fqn('a').set(10), string('value is ', var(fqn('a')), ' yo'))
      evaluate(a_block).should == "value is 10 yo"
    end
    it "should interpolate any expression in a text expression, \"${var*2}\"" do
      a_block = block(fqn('a').set(5), string('value is ', text(var(fqn('a')) * 2) , ' yo'))
      evaluate(a_block).should == "value is 10 yo"
    end
    it "should interpolate any expression without a text expression, \"${$var*2}\"" do
      # there is no concrete syntax for this, but the parser can generate this simpler
      # equivalent form where the expression is not wrapped in a TextExpression
      a_block = block(fqn('a').set(5), string('value is ', var(fqn('a')) * 2 , ' yo'))
      evaluate(a_block).should == "value is 10 yo"
    end
  end
end
