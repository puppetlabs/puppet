#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'

# EParser is the expression based grammar
require 'puppet/pops/impl/parser/eparser'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/transformer_rspec_helper')
  
describe Puppet::Pops::Impl::Parser::Parser do
  EvaluationError ||= Puppet::Pops::EvaluationError
  Model ||= Puppet::Pops::API::Model
  AST ||= Puppet::Parser::AST
  include TransformerRspecHelper
  
  context "When running these transformation examples, the setup" do
    it "should be able to transform a model" do
      transform(literal(10)).class.should == AST::Name
    end
    
    it "ast dumper should dump numbers as literal numbers" do
      astdump(transform(parse('10'))).should   == "10"
      astdump(transform(parse('0x10'))).should == "0x10"
      astdump(transform(parse('010'))).should  == "010"
    end

    it "ast dumper should transform if not already transformed" do
      astdump(parse('10')).should   == "10"
    end
    
    it "should include tree dumpers for convenient string comparisons" do
      x = literal(10) + literal(20)
      dump(x).should == "(+ 10 20)"
      astdump(transform(x)).should == "(+ 10 20)"
    end
  
    it "should use a Factory that applies arithmetic precedence to operators" do
      x = literal(2) * literal(10) + literal(20)
      astdump(transform(x)).should == "(+ (* 2 10) 20)"
    end
    
    it "should parse a code string and return a model" do
      model = parse("$a = 10").current
      model.class.should == Model::AssignmentExpression
      dump(model).should == "(= $a 10)"
    end
  end
  
  context "When the parser parses arithmetic" do
    
    context "with Integers" do
      it "$a = 2 + 2"   do; astdump(parse("$a = 2 + 2")).should == "(= $a (+ 2 2))"      ; end  
      it "$a = 7 - 3"   do; astdump(parse("$a = 7 - 3")).should == "(= $a (- 7 3))"      ; end
      it "$a = 6 * 3"   do; astdump(parse("$a = 6 * 3")).should == "(= $a (* 6 3))"      ; end
      it "$a = 6 / 3"   do; astdump(parse("$a = 6 / 3")).should == "(= $a (/ 6 3))"      ; end
      it "$a = 6 % 3"   do; astdump(parse("$a = 6 % 3")).should == "(= $a (% 6 3))"      ; end
      it "$a = -(6/3)"  do; astdump(parse("$a = -(6/3)")).should == "(= $a (- (/ 6 3)))" ; end
      it "$a = -6/3"    do; astdump(parse("$a = -6/3")).should == "(= $a (/ (- 6) 3))"   ; end
      it "$a = 8 >> 1 " do; astdump(parse("$a = 8 >> 1")).should == "(= $a (>> 8 1))"    ; end
      it "$a = 8 << 1 " do; astdump(parse("$a = 8 << 1")).should == "(= $a (<< 8 1))"    ; end
    end
    
    context "with Floats" do
      it "$a = 2.2 + 2.2"  do; astdump(parse("$a = 2.2 + 2.2")).should == "(= $a (+ 2.2 2.2))"      ; end
      it "$a = 7.7 - 3.3"  do; astdump(parse("$a = 7.7 - 3.3")).should == "(= $a (- 7.7 3.3))"      ; end
      it "$a = 6.1 * 3.1"  do; astdump(parse("$a = 6.1 - 3.1")).should == "(= $a (- 6.1 3.1))"      ; end
      it "$a = 6.6 / 3.3"  do; astdump(parse("$a = 6.6 / 3.3")).should == "(= $a (/ 6.6 3.3))"      ; end
      it "$a = -(6.0/3.0)" do; astdump(parse("$a = -(6.0/3.0)")).should == "(= $a (- (/ 6.0 3.0)))" ; end
      it "$a = -6.0/3.0"   do; astdump(parse("$a = -6.0/3.0")).should == "(= $a (/ (- 6.0) 3.0))"   ; end
      it "$a = 3.14 << 2"  do; astdump(parse("$a = 3.14 << 2")).should == "(= $a (<< 3.14 2))"      ; end
      it "$a = 3.14 >> 2"  do; astdump(parse("$a = 3.14 >> 2")).should == "(= $a (>> 3.14 2))"      ; end
    end
    
    context "with hex and octal Integer values" do
      it "$a = 0xAB + 0xCD" do; astdump(parse("$a = 0xAB + 0xCD")).should == "(= $a (+ 0xAB 0xCD))"  ; end  
      it "$a = 0777 - 0333" do; astdump(parse("$a = 0777 - 0333")).should == "(= $a (- 0777 0333))"  ; end
    end
    
    context "with strings requiring boxing to Numeric" do
      # In AST, there is no difference, the ast dumper prints all numbers without quotes - they are still
      # strings
      it "$a = '2' + '2'"       do; astdump(parse("$a = '2' + '2'")).should == "(= $a (+ 2 2))"             ; end
      it "$a = '2.2' + '0.2'"   do; astdump(parse("$a = '2.2' + '0.2'")).should == "(= $a (+ 2.2 0.2))"     ; end
      it "$a = '0xab' + '0xcd'" do; astdump(parse("$a = '0xab' + '0xcd'")).should == "(= $a (+ 0xab 0xcd))" ; end
      it "$a = '0777' + '0333'" do; astdump(parse("$a = '0777' + '0333'")).should == "(= $a (+ 0777 0333))" ; end    
    end
    context "precedence should be correct" do
      it "$a = 1 + 2 * 3" do; astdump(parse("$a = 1 + 2 * 3")).should == "(= $a (+ 1 (* 2 3)))"; end
      it "$a = 1 + 2 % 3" do; astdump(parse("$a = 1 + 2 % 3")).should == "(= $a (+ 1 (% 2 3)))"; end
      it "$a = 1 + 2 / 3" do; astdump(parse("$a = 1 + 2 / 3")).should == "(= $a (+ 1 (/ 2 3)))"; end
      it "$a = 1 + 2 << 3" do; astdump(parse("$a = 1 + 2 << 3")).should == "(= $a (<< (+ 1 2) 3))"; end
      it "$a = 1 + 2 >> 3" do; astdump(parse("$a = 1 + 2 >> 3")).should == "(= $a (>> (+ 1 2) 3))"; end
    end
    context "parentheses alter precedence" do
      it "$a = (1 + 2) * 3" do; astdump(parse("$a = (1 + 2) * 3")).should == "(= $a (* (+ 1 2) 3))"; end
      it "$a = (1 + 2) / 3" do; astdump(parse("$a = (1 + 2) / 3")).should == "(= $a (/ (+ 1 2) 3))"; end
    end
  end
  
  context "When the evaluator performs boolean operations" do
    context "using operators AND OR NOT" do
      it "$a = true  and true" do; astdump(parse("$a = true and true")).should == "(= $a (&& true true))"; end
      it "$a = true  or true"  do; astdump(parse("$a = true or true")).should == "(= $a (|| true true))" ; end
      it "$a = !true"          do; astdump(parse("$a = !true")).should == "(= $a (! true))"              ; end
    end
    
    context "precedence should be correct" do
      it "$a = false or true and true" do
        astdump(parse("$a = false or true and true")).should == "(= $a (|| false (&& true true)))"
      end
      it "$a = (false or true) and true" do
        astdump(parse("$a = (false or true) and true")).should == "(= $a (&& (|| false true) true))"
      end
      it "$a = !true or true and true" do
        astdump(parse("$a = !false or true and true")).should == "(= $a (|| (! false) (&& true true)))"
      end
    end
    
    # Possibly change to check of literal expressions   
    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        astdump(parse("! 'x'")).should == "(! 'x')"
      end
      it "''             == false" do
        astdump(parse("! ''")).should == "(! '')"
      end
      it ":undef         == false" do
        astdump(parse("! undef")).should == "(! :undef)"
      end
    end    
  end
  
  context "When parsing comparisons" do
    context "of string values" do
      it "$a = 'a' == 'a'"  do; astdump(parse("$a = 'a' == 'a'")).should == "(= $a (== 'a' 'a'))"   ; end 
      it "$a = 'a' != 'a'"  do; astdump(parse("$a = 'a' != 'a'")).should == "(= $a (!= 'a' 'a'))"   ; end 
      it "$a = 'a' < 'b'"   do; astdump(parse("$a = 'a' < 'b'")).should == "(= $a (< 'a' 'b'))"     ; end 
      it "$a = 'a' > 'b'"   do; astdump(parse("$a = 'a' > 'b'")).should == "(= $a (> 'a' 'b'))"     ; end 
      it "$a = 'a' <= 'b'"  do; astdump(parse("$a = 'a' <= 'b'")).should == "(= $a (<= 'a' 'b'))"   ; end 
      it "$a = 'a' >= 'b'"  do; astdump(parse("$a = 'a' >= 'b'")).should == "(= $a (>= 'a' 'b'))"   ; end       
    end
    context "of integer values" do
      it "$a = 1 == 1"  do; astdump(parse("$a = 1 == 1")).should == "(= $a (== 1 1))"   ; end 
      it "$a = 1 != 1"  do; astdump(parse("$a = 1 != 1")).should == "(= $a (!= 1 1))"   ; end 
      it "$a = 1 < 2"   do; astdump(parse("$a = 1 < 2")).should == "(= $a (< 1 2))"     ; end 
      it "$a = 1 > 2"   do; astdump(parse("$a = 1 > 2")).should == "(= $a (> 1 2))"     ; end 
      it "$a = 1 <= 2"  do; astdump(parse("$a = 1 <= 2")).should == "(= $a (<= 1 2))"   ; end 
      it "$a = 1 >= 2"  do; astdump(parse("$a = 1 >= 2")).should == "(= $a (>= 1 2))"   ; end       
    end
    context "of regular expressions (parse errors)" do
      # Not supported in concrete syntax
      it "$a = /.*/ == /.*/" do
        expect {  parse("$a = /.*/ == /.*/") }.to raise_error(Puppet::ParseError)
      end 
      it "$a = /.*/ != /a.*/" do
        expect {  parse("$a = /.*/ != /.*/") }.to raise_error(Puppet::ParseError)
      end 
    end
  end
  context "When parsing Regular Expression matching" do
    it "$a = 'a' =~ /.*/"    do; astdump(parse("$a = 'a' =~ /.*/")).should == "(= $a (=~ 'a' /.*/))"      ; end
    it "$a = 'a' =~ '.*'"    do; astdump(parse("$a = 'a' =~ '.*'")).should == "(= $a (=~ 'a' '.*'))"      ; end
    it "$a = 'a' !~ /b.*/"   do; astdump(parse("$a = 'a' !~ /b.*/")).should == "(= $a (!~ 'a' /b.*/))"    ; end
    it "$a = 'a' !~ 'b.*'"   do; astdump(parse("$a = 'a' !~ 'b.*'")).should == "(= $a (!~ 'a' 'b.*'))"    ; end
  end
  context "When parsing Lists" do
    it "$a = []" do
      astdump(parse("$a = []")).should == "(= $a ([]))"
    end
    it "$a = [1]" do
      astdump(parse("$a = [1]")).should == "(= $a ([] 1))"
    end
    it "$a = [1,2,3]" do
      astdump(parse("$a = [1,2,3]")).should == "(= $a ([] 1 2 3))"
    end
    it "[...[...[]]] should create nested arrays without trouble" do
      astdump(parse("$a = [1,[2.0, 2.1, [2.2]],[3.0, 3.1]]")).should == "(= $a ([] 1 ([] 2.0 2.1 ([] 2.2)) ([] 3.0 3.1)))"
    end
    it "$a = [2 + 2]" do
      astdump(parse("$a = [2+2]")).should == "(= $a ([] (+ 2 2)))"
    end
    it "$a [1,2,3] == [1,2,3]" do
      astdump(parse("$a = [1,2,3] == [1,2,3]")).should == "(= $a (== ([] 1 2 3) ([] 1 2 3)))"
    end
  end
  context "When parsing indexed access" do
    it "$a = $b[2]" do
      astdump(parse("$a = $b[2]")).should == "(= $a (slice $b 2))"
    end
    it "$a = [1, 2, 3][2]" do
      # pending "hasharrayaccess only operates on variable as LHS due to clash with resource reference in puppet 3.x"
      astdump(parse("$a = [1,2,3][2]")).should == "(= $a (slice ([] 1 2 3) 2))"
    end
    it "$a = {'a' => 1, 'b' => 2}['b']" do
      #pending "hasharrayaccess only operates on variable as LHS due to clash with resource reference in puppet 3.x"
      astdump(parse("$a = {'a'=>1,'b' =>2}[b]")).should == "(= $a (slice ({} ('a' 1) ('b' 2)) b))"
    end

  end
  
  context "When parsing Hashes" do
    it "(selftest) these tests depends on that the factory creates hash with literal expressions" do
      x = literal({'a'=>1,'b'=>2}).current
      x.entries.each {|v| v.kind_of?(Puppet::Pops::API::Model::KeyedEntry).should == true }
      Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x).should == "({} ('a' 1) ('b' 2))"
    end
    it "should create a  Hash when evaluating a LiteralHash" do
      astdump(parse("$a = {'a'=>1,'b'=>2}")).should == "(= $a ({} ('a' 1) ('b' 2)))"
    end
    it "$a = {...{...{}}} should create nested hashes without trouble" do
      astdump(parse("$a = {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}")).should == "(= $a ({} ('a' 1) ('b' ({} ('x' 2.1) ('y' 2.2)))))"
    end
    it "$a = {'a'=> 2 + 2} should evaluate values in entries" do
      astdump(parse("$a = {'a'=>2+2}")).should == "(= $a ({} ('a' (+ 2 2))))"
    end
    it "$a = {'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2}" do
      astdump(parse("$a = {'a'=>1,'b'=>2} == {'a'=>1,'b'=>2}")).should == "(= $a (== ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))"
    end
    it "$a = {'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3}" do
      astdump(parse("$a = {'a'=>1,'b'=>2} != {'a'=>1,'b'=>2}")).should == "(= $a (!= ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))"
    end
  end
  context "When parsing the 'in' operator" do
    it "with integer in a list" do
      astdump(parse("$a = 1 in [1,2,3]")).should == "(= $a (in 1 ([] 1 2 3)))"
    end
    it "with string key in a hash" do
      astdump(parse("$a = 'a' in {'x'=>1, 'a'=>2, 'y'=> 3}")).should == "(= $a (in 'a' ({} ('x' 1) ('a' 2) ('y' 3))))"
    end
    it "with substrings of a string" do
      astdump(parse("$a = 'ana' in 'bananas'")).should == "(= $a (in 'ana' 'bananas'))"
    end
    it "with sublist in a list" do
      astdump(parse("$a = [2,3] in [1,2,3]")).should == "(= $a (in ([] 2 3) ([] 1 2 3)))"
    end
  end
  context "When parsing string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      astdump(parse("$a = \"$var\"")).should == "(= $a (cat '' (str $var) ''))"
    end
    it "should interpolate a variable in a text expression, \"${$var}\"" do
      astdump(parse("$a = \"${$var}\"")).should == "(= $a (cat '' (str $var) ''))"
    end
    it "should interpolate a variable, \"yo${var}yo\"" do
      astdump(parse("$a = \"yo${var}yo\"")).should == "(= $a (cat 'yo' (str $var) 'yo'))"
    end
    it "should interpolate any expression in a text expression, \"${var*2}\"" do
      astdump(parse("$a = \"yo${var+2}yo\"")).should == "(= $a (cat 'yo' (str (+ $var 2)) 'yo'))"
    end
  end
end