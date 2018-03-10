#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing basic expressions" do
  include ParserRspecHelper

  context "When the parser parses arithmetic" do
    context "with Integers" do
      it "$a = 2 + 2"   do; expect(dump(parse("$a = 2 + 2"))).to eq("(= $a (+ 2 2))")      ; end
      it "$a = 7 - 3"   do; expect(dump(parse("$a = 7 - 3"))).to eq("(= $a (- 7 3))")      ; end
      it "$a = 6 * 3"   do; expect(dump(parse("$a = 6 * 3"))).to eq("(= $a (* 6 3))")      ; end
      it "$a = 6 / 3"   do; expect(dump(parse("$a = 6 / 3"))).to eq("(= $a (/ 6 3))")      ; end
      it "$a = 6 % 3"   do; expect(dump(parse("$a = 6 % 3"))).to eq("(= $a (% 6 3))")      ; end
      it "$a = -(6/3)"  do; expect(dump(parse("$a = -(6/3)"))).to eq("(= $a (- (/ 6 3)))") ; end
      it "$a = -6/3"    do; expect(dump(parse("$a = -6/3"))).to eq("(= $a (/ (- 6) 3))")   ; end
      it "$a = 8 >> 1 " do; expect(dump(parse("$a = 8 >> 1"))).to eq("(= $a (>> 8 1))")    ; end
      it "$a = 8 << 1 " do; expect(dump(parse("$a = 8 << 1"))).to eq("(= $a (<< 8 1))")    ; end
    end

    context "with Floats" do
      it "$a = 2.2 + 2.2"  do; expect(dump(parse("$a = 2.2 + 2.2"))).to eq("(= $a (+ 2.2 2.2))")      ; end
      it "$a = 7.7 - 3.3"  do; expect(dump(parse("$a = 7.7 - 3.3"))).to eq("(= $a (- 7.7 3.3))")      ; end
      it "$a = 6.1 * 3.1"  do; expect(dump(parse("$a = 6.1 - 3.1"))).to eq("(= $a (- 6.1 3.1))")      ; end
      it "$a = 6.6 / 3.3"  do; expect(dump(parse("$a = 6.6 / 3.3"))).to eq("(= $a (/ 6.6 3.3))")      ; end
      it "$a = -(6.0/3.0)" do; expect(dump(parse("$a = -(6.0/3.0)"))).to eq("(= $a (- (/ 6.0 3.0)))") ; end
      it "$a = -6.0/3.0"   do; expect(dump(parse("$a = -6.0/3.0"))).to eq("(= $a (/ (- 6.0) 3.0))")   ; end
      it "$a = 3.14 << 2"  do; expect(dump(parse("$a = 3.14 << 2"))).to eq("(= $a (<< 3.14 2))")      ; end
      it "$a = 3.14 >> 2"  do; expect(dump(parse("$a = 3.14 >> 2"))).to eq("(= $a (>> 3.14 2))")      ; end
    end

    context "with hex and octal Integer values" do
      it "$a = 0xAB + 0xCD" do; expect(dump(parse("$a = 0xAB + 0xCD"))).to eq("(= $a (+ 0xAB 0xCD))")  ; end
      it "$a = 0777 - 0333" do; expect(dump(parse("$a = 0777 - 0333"))).to eq("(= $a (- 0777 0333))")  ; end
    end

    context "with strings requiring boxing to Numeric" do
      # Test that numbers in string form does not turn into numbers
      it "$a = '2' + '2'"       do; expect(dump(parse("$a = '2' + '2'"))).to eq("(= $a (+ '2' '2'))")             ; end
      it "$a = '2.2' + '0.2'"   do; expect(dump(parse("$a = '2.2' + '0.2'"))).to eq("(= $a (+ '2.2' '0.2'))")     ; end
      it "$a = '0xab' + '0xcd'" do; expect(dump(parse("$a = '0xab' + '0xcd'"))).to eq("(= $a (+ '0xab' '0xcd'))") ; end
      it "$a = '0777' + '0333'" do; expect(dump(parse("$a = '0777' + '0333'"))).to eq("(= $a (+ '0777' '0333'))") ; end
    end

    context "precedence should be correct" do
      it "$a = 1 + 2 * 3" do; expect(dump(parse("$a = 1 + 2 * 3"))).to eq("(= $a (+ 1 (* 2 3)))"); end
      it "$a = 1 + 2 % 3" do; expect(dump(parse("$a = 1 + 2 % 3"))).to eq("(= $a (+ 1 (% 2 3)))"); end
      it "$a = 1 + 2 / 3" do; expect(dump(parse("$a = 1 + 2 / 3"))).to eq("(= $a (+ 1 (/ 2 3)))"); end
      it "$a = 1 + 2 << 3" do; expect(dump(parse("$a = 1 + 2 << 3"))).to eq("(= $a (<< (+ 1 2) 3))"); end
      it "$a = 1 + 2 >> 3" do; expect(dump(parse("$a = 1 + 2 >> 3"))).to eq("(= $a (>> (+ 1 2) 3))"); end
    end

    context "parentheses alter precedence" do
      it "$a = (1 + 2) * 3" do; expect(dump(parse("$a = (1 + 2) * 3"))).to eq("(= $a (* (+ 1 2) 3))"); end
      it "$a = (1 + 2) / 3" do; expect(dump(parse("$a = (1 + 2) / 3"))).to eq("(= $a (/ (+ 1 2) 3))"); end
    end
  end

  context "When the evaluator performs boolean operations" do
    context "using operators AND OR NOT" do
      it "$a = true  and true" do; expect(dump(parse("$a = true and true"))).to eq("(= $a (&& true true))"); end
      it "$a = true  or true"  do; expect(dump(parse("$a = true or true"))).to eq("(= $a (|| true true))") ; end
      it "$a = !true"          do; expect(dump(parse("$a = !true"))).to eq("(= $a (! true))")              ; end
    end

    context "precedence should be correct" do
      it "$a = false or true and true" do
        expect(dump(parse("$a = false or true and true"))).to eq("(= $a (|| false (&& true true)))")
      end

      it "$a = (false or true) and true" do
        expect(dump(parse("$a = (false or true) and true"))).to eq("(= $a (&& (|| false true) true))")
      end

      it "$a = !true or true and true" do
        expect(dump(parse("$a = !false or true and true"))).to eq("(= $a (|| (! false) (&& true true)))")
      end
    end

    # Possibly change to check of literal expressions
    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        expect(dump(parse("! 'x'"))).to eq("(! 'x')")
      end

      it "''             == false" do
        expect(dump(parse("! ''"))).to eq("(! '')")
      end

      it ":undef         == false" do
        expect(dump(parse("! undef"))).to eq("(! :undef)")
      end
    end
  end

  context "When parsing comparisons" do
    context "of string values" do
      it "$a = 'a' == 'a'"  do; expect(dump(parse("$a = 'a' == 'a'"))).to eq("(= $a (== 'a' 'a'))")   ; end
      it "$a = 'a' != 'a'"  do; expect(dump(parse("$a = 'a' != 'a'"))).to eq("(= $a (!= 'a' 'a'))")   ; end
      it "$a = 'a' < 'b'"   do; expect(dump(parse("$a = 'a' < 'b'"))).to eq("(= $a (< 'a' 'b'))")     ; end
      it "$a = 'a' > 'b'"   do; expect(dump(parse("$a = 'a' > 'b'"))).to eq("(= $a (> 'a' 'b'))")     ; end
      it "$a = 'a' <= 'b'"  do; expect(dump(parse("$a = 'a' <= 'b'"))).to eq("(= $a (<= 'a' 'b'))")   ; end
      it "$a = 'a' >= 'b'"  do; expect(dump(parse("$a = 'a' >= 'b'"))).to eq("(= $a (>= 'a' 'b'))")   ; end
    end

    context "of integer values" do
      it "$a = 1 == 1"  do; expect(dump(parse("$a = 1 == 1"))).to eq("(= $a (== 1 1))")   ; end
      it "$a = 1 != 1"  do; expect(dump(parse("$a = 1 != 1"))).to eq("(= $a (!= 1 1))")   ; end
      it "$a = 1 < 2"   do; expect(dump(parse("$a = 1 < 2"))).to eq("(= $a (< 1 2))")     ; end
      it "$a = 1 > 2"   do; expect(dump(parse("$a = 1 > 2"))).to eq("(= $a (> 1 2))")     ; end
      it "$a = 1 <= 2"  do; expect(dump(parse("$a = 1 <= 2"))).to eq("(= $a (<= 1 2))")   ; end
      it "$a = 1 >= 2"  do; expect(dump(parse("$a = 1 >= 2"))).to eq("(= $a (>= 1 2))")   ; end
    end

    context "of regular expressions (parse errors)" do
      # Not supported in concrete syntax
      it "$a = /.*/ == /.*/" do
        expect(dump(parse("$a = /.*/ == /.*/"))).to eq("(= $a (== /.*/ /.*/))")
      end

      it "$a = /.*/ != /a.*/" do
        expect(dump(parse("$a = /.*/ != /.*/"))).to eq("(= $a (!= /.*/ /.*/))")
      end
    end
  end

  context "When parsing Regular Expression matching" do
    it "$a = 'a' =~ /.*/"    do; expect(dump(parse("$a = 'a' =~ /.*/"))).to eq("(= $a (=~ 'a' /.*/))")      ; end
    it "$a = 'a' =~ '.*'"    do; expect(dump(parse("$a = 'a' =~ '.*'"))).to eq("(= $a (=~ 'a' '.*'))")      ; end
    it "$a = 'a' !~ /b.*/"   do; expect(dump(parse("$a = 'a' !~ /b.*/"))).to eq("(= $a (!~ 'a' /b.*/))")    ; end
    it "$a = 'a' !~ 'b.*'"   do; expect(dump(parse("$a = 'a' !~ 'b.*'"))).to eq("(= $a (!~ 'a' 'b.*'))")    ; end
  end

  context "When parsing unfold" do
    it "$a = *[1,2]" do; expect(dump(parse("$a = *[1,2]"))).to eq("(= $a (unfold ([] 1 2)))") ; end
    it "$a = *1"     do; expect(dump(parse("$a = *1"))).to eq("(= $a (unfold 1))") ; end
    it "$a = *[1,a => 2]" do; expect(dump(parse("$a = *[1,a => 2]"))).to eq("(= $a (unfold ([] 1 ({} (a 2)))))") ; end
  end

  context "When parsing Lists" do
    it "$a = []" do
      expect(dump(parse("$a = []"))).to eq("(= $a ([]))")
    end

    it "$a = [1]" do
      expect(dump(parse("$a = [1]"))).to eq("(= $a ([] 1))")
    end

    it "$a = [1,2,3]" do
      expect(dump(parse("$a = [1,2,3]"))).to eq("(= $a ([] 1 2 3))")
    end

    it "$a = [1,a => 2]" do
      expect(dump(parse("$a = [1,a => 2]"))).to eq('(= $a ([] 1 ({} (a 2))))')
    end

    it "$a = [1,a => 2, 3]" do
      expect(dump(parse("$a = [1,a => 2, 3]"))).to eq('(= $a ([] 1 ({} (a 2)) 3))')
    end

    it "$a = [1,a => 2, b => 3]" do
      expect(dump(parse("$a = [1,a => 2, b => 3]"))).to eq('(= $a ([] 1 ({} (a 2) (b 3))))')
    end

    it "$a = [1,a => 2, b => 3, 4]" do
      expect(dump(parse("$a = [1,a => 2, b => 3, 4]"))).to eq('(= $a ([] 1 ({} (a 2) (b 3)) 4))')
    end

    it "$a = [{ x => y }, a => 2, b => 3, { z => p }]" do
      expect(dump(parse("$a = [{ x => y }, a => 2, b => 3, { z => p }]"))).to eq('(= $a ([] ({} (x y)) ({} (a 2) (b 3)) ({} (z p))))')
    end

    it "[...[...[]]] should create nested arrays without trouble" do
      expect(dump(parse("$a = [1,[2.0, 2.1, [2.2]],[3.0, 3.1]]"))).to eq("(= $a ([] 1 ([] 2.0 2.1 ([] 2.2)) ([] 3.0 3.1)))")
    end

    it "$a = [2 + 2]" do
      expect(dump(parse("$a = [2+2]"))).to eq("(= $a ([] (+ 2 2)))")
    end

    it "$a [1,2,3] == [1,2,3]" do
      expect(dump(parse("$a = [1,2,3] == [1,2,3]"))).to eq("(= $a (== ([] 1 2 3) ([] 1 2 3)))")
    end

    it "calculates the text length of an empty array" do
      expect(parse("[]").model.body.length).to eq(2)
      expect(parse("[ ]").model.body.length).to eq(3)
    end

    {
      'keyword' => %w(type function),
      'reserved word' => %w(application site produces consumes)
    }.each_pair do |word_type, words|
      words.each do |word|
        it "allows the #{word_type} '#{word}' in a list" do
          expect(dump(parse("$a = [#{word}]"))).to(eq("(= $a ([] '#{word}'))"))
        end

        it "allows the #{word_type} '#{word}' as a key in a hash" do
          expect(dump(parse("$a = {#{word}=>'x'}"))).to(eq("(= $a ({} ('#{word}' 'x')))"))
        end

        it "allows the #{word_type} '#{word}' as a value in a hash" do
          expect(dump(parse("$a = {'x'=>#{word}}"))).to(eq("(= $a ({} ('x' '#{word}')))"))
        end
      end
    end
  end

  context "When parsing indexed access" do
    it "$a = $b[2]" do
      expect(dump(parse("$a = $b[2]"))).to eq("(= $a (slice $b 2))")
    end

    it "$a = $b[2,]" do
      expect(dump(parse("$a = $b[2,]"))).to eq("(= $a (slice $b 2))")
    end

    it "$a = [1, 2, 3][2]" do
      expect(dump(parse("$a = [1,2,3][2]"))).to eq("(= $a (slice ([] 1 2 3) 2))")
    end

    it '$a = [1, 2, 3][a => 2]' do
      expect(dump(parse('$a = [1,2,3][a => 2]'))).to eq('(= $a (slice ([] 1 2 3) ({} (a 2))))')
    end

    it "$a = {'a' => 1, 'b' => 2}['b']" do
      expect(dump(parse("$a = {'a'=>1,'b' =>2}[b]"))).to eq("(= $a (slice ({} ('a' 1) ('b' 2)) b))")
    end
  end

  context 'When parsing type aliases' do
    it 'type A = B' do
      expect(dump(parse('type A = B'))).to eq('(type-alias A B)')
    end

    it 'type A = B[]' do
      expect{parse('type A = B[]')}.to raise_error(/Syntax error at '\]'/)
    end

    it 'type A = B[,]' do
      expect{parse('type A = B[,]')}.to raise_error(/Syntax error at ','/)
    end

    it 'type A = B[C]' do
      expect(dump(parse('type A = B[C]'))).to eq('(type-alias A (slice B C))')
    end

    it 'type A = B[C,]' do
      expect(dump(parse('type A = B[C,]'))).to eq('(type-alias A (slice B C))')
    end

    it 'type A = B[C,D]' do
      expect(dump(parse('type A = B[C,D]'))).to eq('(type-alias A (slice B (C D)))')
    end

    it 'type A = B[C,D,]' do
      expect(dump(parse('type A = B[C,D,]'))).to eq('(type-alias A (slice B (C D)))')
    end
  end

  context "When parsing assignments" do
    it "Should allow simple assignment" do
      expect(dump(parse("$a = 10"))).to eq("(= $a 10)")
    end

    it "Should allow append assignment" do
      expect(dump(parse("$a += 10"))).to eq("(+= $a 10)")
    end

    it "Should allow without assignment" do
      expect(dump(parse("$a -= 10"))).to eq("(-= $a 10)")
    end

    it "Should allow chained assignment" do
      expect(dump(parse("$a = $b = 10"))).to eq("(= $a (= $b 10))")
    end

    it "Should allow chained assignment with expressions" do
      expect(dump(parse("$a = 1 + ($b = 10)"))).to eq("(= $a (+ 1 (= $b 10)))")
    end
  end

  context "When parsing Hashes" do
    it "should create a  Hash when evaluating a LiteralHash" do
      expect(dump(parse("$a = {'a'=>1,'b'=>2}"))).to eq("(= $a ({} ('a' 1) ('b' 2)))")
    end

    it "$a = {...{...{}}} should create nested hashes without trouble" do
      expect(dump(parse("$a = {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}"))).to eq("(= $a ({} ('a' 1) ('b' ({} ('x' 2.1) ('y' 2.2)))))")
    end

    it "$a = {'a'=> 2 + 2} should evaluate values in entries" do
      expect(dump(parse("$a = {'a'=>2+2}"))).to eq("(= $a ({} ('a' (+ 2 2))))")
    end

    it "$a = {'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2}" do
      expect(dump(parse("$a = {'a'=>1,'b'=>2} == {'a'=>1,'b'=>2}"))).to eq("(= $a (== ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))")
    end

    it "$a = {'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3}" do
      expect(dump(parse("$a = {'a'=>1,'b'=>2} != {'a'=>1,'b'=>2}"))).to eq("(= $a (!= ({} ('a' 1) ('b' 2)) ({} ('a' 1) ('b' 2))))")
    end

    it "$a = 'a' => 1" do
      expect{parse("$a = 'a' => 1")}.to raise_error(/Syntax error at '=>'/)
    end

    it "$a = { 'a' => 'b' => 1 }" do
      expect{parse("$a = { 'a' => 'b' => 1 }")}.to raise_error(/Syntax error at '=>'/)
    end

    it "calculates the text length of an empty hash" do
      expect(parse("{}").model.body.length).to eq(2)
      expect(parse("{ }").model.body.length).to eq(3)
    end
  end

  context "When parsing the 'in' operator" do
    it "with integer in a list" do
      expect(dump(parse("$a = 1 in [1,2,3]"))).to eq("(= $a (in 1 ([] 1 2 3)))")
    end

    it "with string key in a hash" do
      expect(dump(parse("$a = 'a' in {'x'=>1, 'a'=>2, 'y'=> 3}"))).to eq("(= $a (in 'a' ({} ('x' 1) ('a' 2) ('y' 3))))")
    end

    it "with substrings of a string" do
      expect(dump(parse("$a = 'ana' in 'bananas'"))).to eq("(= $a (in 'ana' 'bananas'))")
    end

    it "with sublist in a list" do
      expect(dump(parse("$a = [2,3] in [1,2,3]"))).to eq("(= $a (in ([] 2 3) ([] 1 2 3)))")
    end
  end

  context "When parsing string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      expect(dump(parse("$a = \"$var\""))).to eq("(= $a (cat (str $var)))")
    end

    it "should interpolate a variable in a text expression, \"${$var}\"" do
      expect(dump(parse("$a = \"${$var}\""))).to eq("(= $a (cat (str $var)))")
    end

    it "should interpolate a variable, \"yo${var}yo\"" do
      expect(dump(parse("$a = \"yo${var}yo\""))).to eq("(= $a (cat 'yo' (str $var) 'yo'))")
    end

    it "should interpolate any expression in a text expression, \"${$var*2}\"" do
      expect(dump(parse("$a = \"yo${$var+2}yo\""))).to eq("(= $a (cat 'yo' (str (+ $var 2)) 'yo'))")
    end

    it "should not interpolate names as variable in expression, \"${notvar*2}\"" do
      expect(dump(parse("$a = \"yo${notvar+2}yo\""))).to eq("(= $a (cat 'yo' (str (+ notvar 2)) 'yo'))")
    end

    it "should interpolate name as variable in access expression, \"${var[0]}\"" do
      expect(dump(parse("$a = \"yo${var[0]}yo\""))).to eq("(= $a (cat 'yo' (str (slice $var 0)) 'yo'))")
    end

    it "should interpolate name as variable in method call, \"${var.foo}\"" do
      expect(dump(parse("$a = \"yo${$var.foo}yo\""))).to eq("(= $a (cat 'yo' (str (call-method (. $var foo))) 'yo'))")
    end

    it "should interpolate name as variable in method call, \"${var.foo}\"" do
      expect(dump(parse("$a = \"yo${var.foo}yo\""))).to eq("(= $a (cat 'yo' (str (call-method (. $var foo))) 'yo'))")
      expect(dump(parse("$a = \"yo${var.foo.bar}yo\""))).to eq("(= $a (cat 'yo' (str (call-method (. (call-method (. $var foo)) bar))) 'yo'))")
    end

    it "should interpolate interpolated expressions with a variable, \"yo${\"$var\"}yo\"" do
      expect(dump(parse("$a = \"yo${\"$var\"}yo\""))).to eq("(= $a (cat 'yo' (str (cat (str $var))) 'yo'))")
    end

    it "should interpolate interpolated expressions with an expression, \"yo${\"${$var+2}\"}yo\"" do
      expect(dump(parse("$a = \"yo${\"${$var+2}\"}yo\""))).to eq("(= $a (cat 'yo' (str (cat (str (+ $var 2)))) 'yo'))")
    end
  end
end
