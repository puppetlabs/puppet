#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

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
      it "1.0 == 1  == true"   do; evaluate(literal(1.0)   == literal(1)).should == true     ; end
      it "1.0 < 2   == true"   do; evaluate(literal(1.0)   <  literal(2)).should == true     ; end
      it "'1.0' < 'a' == true" do; evaluate(literal('1.0') <  literal('a')).should == true   ; end
      it "'1.0' < ''  == true" do; evaluate(literal('1.0') <  literal('')).should == false   ; end
      it "'1.0' < ' ' == true" do; evaluate(literal('1.0') <  literal(' ')).should == false   ; end
      it "'a' > '1.0' == true" do; evaluate(literal('a')   >  literal('1.0')).should == true ; end
    end

    context "of unsupported mixed value types" do
      it "'1' < 1.1 == true"   do
        expect{ evaluate(literal('1') <  literal(1.1))}.to raise_error(/String < Float/)
      end
      it "'1.0' < 1.1 == true" do
        expect{evaluate(literal('1.0') <  literal(1.1))}.to raise_error(/String < Float/)
      end
      it "undef < 1.1 == true" do
        expect{evaluate(literal(nil) <  literal(1.1))}.to raise_error(/Undef Value < Float/)
      end
    end

    context "of regular expressions" do
      it "/.*/ == /.*/  == true"   do; evaluate(literal(/.*/) == literal(/.*/)).should == true   ; end
      it "/.*/ != /a.*/ == true"   do; evaluate(literal(/.*/).ne(literal(/a.*/))).should == true ; end
    end

    context "of booleans" do
      it "true  == true  == true"    do; evaluate(literal(true) == literal(true)).should == true  ; end;
      it "false == false == true"    do; evaluate(literal(false) == literal(false)).should == true ; end;
      it "true == false  != true"    do; evaluate(literal(true) == literal(false)).should == false ; end;
      it "false  == ''  == false"    do; evaluate(literal(false) == literal('')).should == false  ; end;
      it "undef  == ''  == false"    do; evaluate(literal(:undef) == literal('')).should == false  ; end;
      it "undef  == undef  == true"  do; evaluate(literal(:undef) == literal(:undef)).should == true  ; end;
      it "nil    == undef  == true"  do; evaluate(literal(nil) == literal(:undef)).should == true  ; end;
    end

    context "of collections" do
      it "[1,2,3] == [1,2,3] == true" do
        evaluate(literal([1,2,3]) == literal([1,2,3])).should == true
        evaluate(literal([1,2,3]).ne(literal([1,2,3]))).should == false
        evaluate(literal([1,2,4]) == literal([1,2,3])).should == false
        evaluate(literal([1,2,4]).ne(literal([1,2,3]))).should == true
      end

      it "{'a'=>1, 'b'=>2} == {'a'=>1, 'b'=>2} == true" do
        evaluate(literal({'a'=>1, 'b'=>2}) == literal({'a'=>1, 'b'=>2})).should == true
        evaluate(literal({'a'=>1, 'b'=>2}).ne(literal({'a'=>1, 'b'=>2}))).should == false
        evaluate(literal({'a'=>1, 'b'=>2}) == literal({'x'=>1, 'b'=>2})).should == false
        evaluate(literal({'a'=>1, 'b'=>2}).ne(literal({'x'=>1, 'b'=>2}))).should == true
      end
    end

    context "of non comparable types" do
      # TODO: Change the exception type
      it "false < true  == error" do; expect { evaluate(literal(true) <  literal(false))}.to raise_error(Puppet::ParseError); end
      it "false <= true == error" do; expect { evaluate(literal(true) <= literal(false))}.to raise_error(Puppet::ParseError); end
      it "false > true  == error" do; expect { evaluate(literal(true) >  literal(false))}.to raise_error(Puppet::ParseError); end
      it "false >= true == error" do; expect { evaluate(literal(true) >= literal(false))}.to raise_error(Puppet::ParseError); end

      it "/a/ < /b/  == error" do; expect { evaluate(literal(/a/) <  literal(/b/))}.to raise_error(Puppet::ParseError); end
      it "/a/ <= /b/ == error" do; expect { evaluate(literal(/a/) <= literal(/b/))}.to raise_error(Puppet::ParseError); end
      it "/a/ > /b/  == error" do; expect { evaluate(literal(/a/) >  literal(/b/))}.to raise_error(Puppet::ParseError); end
      it "/a/ >= /b/ == error" do; expect { evaluate(literal(/a/) >= literal(/b/))}.to raise_error(Puppet::ParseError); end

      it "[1,2,3] < [1,2,3] == error" do
        expect{ evaluate(literal([1,2,3]) < literal([1,2,3]))}.to raise_error(Puppet::ParseError)
      end

      it "[1,2,3] > [1,2,3] == error" do
        expect{ evaluate(literal([1,2,3]) > literal([1,2,3]))}.to raise_error(Puppet::ParseError)
      end

      it "[1,2,3] >= [1,2,3] == error" do
        expect{ evaluate(literal([1,2,3]) >= literal([1,2,3]))}.to raise_error(Puppet::ParseError)
      end

      it "[1,2,3] <= [1,2,3] == error" do
        expect{ evaluate(literal([1,2,3]) <= literal([1,2,3]))}.to raise_error(Puppet::ParseError)
      end

      it "{'a'=>1, 'b'=>2} < {'a'=>1, 'b'=>2} == error" do
        expect{ evaluate(literal({'a'=>1, 'b'=>2}) < literal({'a'=>1, 'b'=>2}))}.to raise_error(Puppet::ParseError)
      end

      it "{'a'=>1, 'b'=>2} > {'a'=>1, 'b'=>2} == error" do
        expect{ evaluate(literal({'a'=>1, 'b'=>2}) > literal({'a'=>1, 'b'=>2}))}.to raise_error(Puppet::ParseError)
      end

      it "{'a'=>1, 'b'=>2} <= {'a'=>1, 'b'=>2} == error" do
        expect{ evaluate(literal({'a'=>1, 'b'=>2}) <= literal({'a'=>1, 'b'=>2}))}.to raise_error(Puppet::ParseError)
      end

      it "{'a'=>1, 'b'=>2} >= {'a'=>1, 'b'=>2} == error" do
        expect{ evaluate(literal({'a'=>1, 'b'=>2}) >= literal({'a'=>1, 'b'=>2}))}.to raise_error(Puppet::ParseError)
      end
    end
  end

  context "When the evaluator performs Regular Expression matching" do
    it "'a' =~ /.*/   == true"    do; evaluate(literal('a') =~ literal(/.*/)).should == true     ; end
    it "'a' =~ '.*'   == true"    do; evaluate(literal('a') =~ literal(".*")).should == true     ; end
    it "'a' !~ /b.*/  == true"    do; evaluate(literal('a').mne(literal(/b.*/))).should == true  ; end
    it "'a' !~ 'b.*'  == true"    do; evaluate(literal('a').mne(literal("b.*"))).should == true  ; end

    it "'a' =~ Pattern['.*'] == true"    do
      evaluate(literal('a') =~ fqr('Pattern')[literal(".*")]).should == true
    end

    it "$a = Pattern['.*']; 'a' =~ $a  == true"    do
      expr = block(var('a').set(fqr('Pattern')['foo']), literal('foo') =~ var('a'))
      evaluate(expr).should == true
    end

    it 'should fail if LHS is not a string' do
      expect { evaluate(literal(666) =~ literal(/6/))}.to raise_error(Puppet::ParseError)
    end
  end

  context "When evaluator evaluates the 'in' operator" do
    it "should find elements in an array" do
      evaluate(literal(1).in(literal([1,2,3]))).should == true
      evaluate(literal(4).in(literal([1,2,3]))).should == false
    end

    it "should find keys in a hash" do
      evaluate(literal('a').in(literal({'x'=>1, 'a'=>2, 'y'=> 3}))).should == true
      evaluate(literal('z').in(literal({'x'=>1, 'a'=>2, 'y'=> 3}))).should == false
    end

    it "should find substrings in a string" do
      evaluate(literal('ana').in(literal('bananas'))).should == true
      evaluate(literal('xxx').in(literal('bananas'))).should == false
    end

    it "should find substrings in a string (regexp)" do
      evaluate(literal(/ana/).in(literal('bananas'))).should == true
      evaluate(literal(/xxx/).in(literal('bananas'))).should == false
    end

    it "should find substrings in a string (ignoring case)" do
      evaluate(literal('ANA').in(literal('bananas'))).should == true
      evaluate(literal('ana').in(literal('BANANAS'))).should == true
      evaluate(literal('xxx').in(literal('BANANAS'))).should == false
    end

    it "should find sublists in a list" do
      evaluate(literal([2,3]).in(literal([1,[2,3],4]))).should == true
      evaluate(literal([2,4]).in(literal([1,[2,3],4]))).should == false
    end

    it "should find sublists in a list (case insensitive)" do
      evaluate(literal(['a','b']).in(literal(['A',['A','B'],'C']))).should == true
      evaluate(literal(['x','y']).in(literal(['A',['A','B'],'C']))).should == false
    end

    it "should find keys in a hash" do
      evaluate(literal('a').in(literal({'a' => 10, 'b' => 20}))).should == true
      evaluate(literal('x').in(literal({'a' => 10, 'b' => 20}))).should == false
    end

    it "should find keys in a hash (case insensitive)" do
      evaluate(literal('A').in(literal({'a' => 10, 'b' => 20}))).should == true
      evaluate(literal('X').in(literal({'a' => 10, 'b' => 20}))).should == false
    end

    it "should find keys in a hash (regexp)" do
      evaluate(literal(/xxx/).in(literal({'abcxxxabc' => 10, 'xyz' => 20}))).should == true
      evaluate(literal(/yyy/).in(literal({'abcxxxabc' => 10, 'xyz' => 20}))).should == false
    end

    it "should find numbers as numbers" do
      evaluate(literal(15).in(literal([1,0xf,2]))).should == true
    end

    it "should not find numbers as strings" do
      evaluate(literal(15).in(literal([1, '0xf',2]))).should == false
      evaluate(literal('15').in(literal([1, 0xf,2]))).should == false
    end

    it "should not find numbers embedded in strings, nor digits in numbers" do
      evaluate(literal(15).in(literal([1, '115', 2]))).should == false
      evaluate(literal(1).in(literal([11, 111, 2]))).should == false
      evaluate(literal('1').in(literal([11, 111, 2]))).should == false
    end

    it 'should find an entry with compatible type in an Array' do
      evaluate(fqr('Array')[fqr('Integer')].in(literal(['a', [1,2,3], 'b']))).should == true
      evaluate(fqr('Array')[fqr('Integer')].in(literal(['a', [1,2,'not integer'], 'b']))).should == false
    end

    it 'should find an entry with compatible type in a Hash' do
      evaluate(fqr('Integer').in(literal({1 => 'a', 'a' => 'b'}))).should == true
      evaluate(fqr('Integer').in(literal({'a' => 'a', 'a' => 'b'}))).should == false
    end
  end
end
