#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/transformer_rspec_helper')

describe "transformation to Puppet AST for basic expressions" do
  include TransformerRspecHelper

  context "When transforming arithmetic" do
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

  context "When transforming boolean operations" do
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

  context "When transforming comparisons" do
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
      # Not supported in concrete syntax (until Lexer2)
      it "$a = /.*/ == /.*/" do
        astdump(parse("$a = /.*/ == /.*/")).should == "(= $a (== /.*/ /.*/))"
      end

      it "$a = /.*/ != /a.*/" do
        astdump(parse("$a = /.*/ != /.*/")).should == "(= $a (!= /.*/ /.*/))"
      end
    end
  end

  context "When transforming Regular Expression matching" do
    it "$a = 'a' =~ /.*/"    do; astdump(parse("$a = 'a' =~ /.*/")).should == "(= $a (=~ 'a' /.*/))"      ; end
    it "$a = 'a' =~ '.*'"    do; astdump(parse("$a = 'a' =~ '.*'")).should == "(= $a (=~ 'a' '.*'))"      ; end
    it "$a = 'a' !~ /b.*/"   do; astdump(parse("$a = 'a' !~ /b.*/")).should == "(= $a (!~ 'a' /b.*/))"    ; end
    it "$a = 'a' !~ 'b.*'"   do; astdump(parse("$a = 'a' !~ 'b.*'")).should == "(= $a (!~ 'a' 'b.*'))"    ; end
  end

  context "When transforming Lists" do
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

  context "When transforming indexed access" do
    it "$a = $b[2]" do
      astdump(parse("$a = $b[2]")).should == "(= $a (slice $b 2))"
    end

    it "$a = [1, 2, 3][2]" do
      astdump(parse("$a = [1,2,3][2]")).should == "(= $a (slice ([] 1 2 3) 2))"
    end

    it "$a = {'a' => 1, 'b' => 2}['b']" do
      astdump(parse("$a = {'a'=>1,'b' =>2}[b]")).should == "(= $a (slice ({} ('a' 1) ('b' 2)) b))"
    end
  end

  context "When transforming Hashes" do
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

  context "When transforming the 'in' operator" do
    it "with integer in a list" do
      astdump(parse("$a = 1 in [1,2,3]")).should == "(= $a (in 1 ([] 1 2 3)))"
    end

    it "with string key in a hash" do
      astdump(parse("$a = 'a' in {'x'=>1, 'a'=>2, 'y'=> 3}")).should == "(= $a (in 'a' ({} ('a' 2) ('x' 1) ('y' 3))))"
    end

    it "with substrings of a string" do
      astdump(parse("$a = 'ana' in 'bananas'")).should == "(= $a (in 'ana' 'bananas'))"
    end

    it "with sublist in a list" do
      astdump(parse("$a = [2,3] in [1,2,3]")).should == "(= $a (in ([] 2 3) ([] 1 2 3)))"
    end
  end

  context "When transforming string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      astdump(parse("$a = \"$var\"")).should == "(= $a (cat '' (str $var) ''))"
    end

    it "should interpolate a variable in a text expression, \"${$var}\"" do
      astdump(parse("$a = \"${$var}\"")).should == "(= $a (cat '' (str $var) ''))"
    end

    it "should interpolate two variables in a text expression" do
      astdump(parse(%q{$a = "xxx $x and $y end"})).should == "(= $a (cat 'xxx ' (str $x) ' and ' (str $y) ' end'))"
    end

    it "should interpolate one variables  followed by parentheses" do
      astdump(parse(%q{$a = "xxx ${x} (yay)"})).should == "(= $a (cat 'xxx ' (str $x) ' (yay)'))"
    end

    it "should interpolate a variable, \"yo${var}yo\"" do
      astdump(parse("$a = \"yo${var}yo\"")).should == "(= $a (cat 'yo' (str $var) 'yo'))"
    end

    it "should interpolate any expression in a text expression, \"${var*2}\"" do
      astdump(parse("$a = \"yo${$var+2}yo\"")).should == "(= $a (cat 'yo' (str (+ $var 2)) 'yo'))"
    end
  end
end
