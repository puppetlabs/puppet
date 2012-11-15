#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Selector do
  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  # Take a code expression containing a selector, and return that portion of
  # the AST.  This does the magic required to make that legal and all.
  def parse(selector)
    Puppet::Parser::Parser.new(scope.environment).
      parse("$foo = #{selector}").
      code[0].value             # extract only the selector
  end

  describe "when evaluating" do
    it "should evaluate param" do
      selector = parse 'value ? { default => result }'
      selector.param.expects(:safeevaluate)
      selector.evaluate(scope)
    end

    it "should try to match each option in sequence" do
      selector = parse '"a" ? { "a" => "a", "b" => "b", default => "default" }'

      order = sequence('evaluation of matching options')
      selector.values.each do |slot|
        slot.param.expects(:evaluate_match).in_sequence(order).returns(false)
      end

      selector.evaluate(scope)
    end

    describe "when scanning values" do
      it "should evaluate and return first matching option" do
        selector = parse '"b" ? { "a" => "=a", "b" => "=b", "c" => "=c" }'
        selector.evaluate(scope).should == '=b'
      end

      it "should evaluate the default option if none matched" do
        selector = parse '"a" ? { "b" => "=b", default => "=default" }'
        selector.evaluate(scope).should == "=default"
      end

      it "should return the default even if that isn't the last option" do
        selector = parse '"a" ? { "b" => "=b", default => "=default", "c" => "=c" }'
        selector.evaluate(scope).should == "=default"
      end

      it "should raise ParseError if nothing matched, and no default" do
        selector = parse '"a" ? { "b" => "=b" }'
        msg = /No matching value for selector param/
        expect { selector.evaluate(scope) }.to raise_error Puppet::ParseError, msg
      end

      it "should unset scope ephemeral variables after option evaluation" do
        selector = parse '"a" ? { "a" => "=a" }'
        scope.expects(:unset_ephemeral_var).with(scope.ephemeral_level)
        selector.evaluate(scope)
      end

      it "should not leak ephemeral variables even if evaluation fails" do
        selector = parse '"a" ? { "b" => "=b" }'
        scope.expects(:unset_ephemeral_var).with(scope.ephemeral_level)
        expect { selector.evaluate(scope) }.to raise_error
      end
    end
  end

  describe "when converting to string" do
    it "should work with a single match" do
      parse('$input ? { "a" => "a+" }').to_s.should == '$input ? { "a" => "a+" }'
    end

    it "should work with multiple matches" do
      parse('$input ? { "a" => "a+", "b" => "b+" }').to_s.
        should == '$input ? { "a" => "a+", "b" => "b+" }'
    end

    it "should preserve order of inputs" do
      match    = ('a' .. 'z').map {|x| "#{x} => #{x}" }.join(', ')
      selector = parse "$input ? { #{match} }"

      selector.to_s.should == "$input ? { #{match} }"
    end
  end
end
