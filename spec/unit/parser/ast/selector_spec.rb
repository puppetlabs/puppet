#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::Selector do
  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  describe "when evaluating", :'fails_on_ruby_1.9.2' => true do

    before :each do
      @param = stub 'param'
      @param.stubs(:safeevaluate).with(@scope).returns("value")

      @value1 = stub 'value1'
      @param1 = stub_everything 'param1'
      @param1.stubs(:safeevaluate).with(@scope).returns(@param1)
      @param1.stubs(:respond_to?).with(:downcase).returns(false)
      @value1.stubs(:param).returns(@param1)
      @value1.stubs(:value).returns(@value1)

      @value2 = stub 'value2'
      @param2 = stub_everything 'param2'
      @param2.stubs(:safeevaluate).with(@scope).returns(@param2)
      @param2.stubs(:respond_to?).with(:downcase).returns(false)
      @value2.stubs(:param).returns(@param2)
      @value2.stubs(:value).returns(@value2)

      @values = stub 'values', :instance_of? => true
      @values.stubs(:each).multiple_yields(@value1, @value2)

      @selector = Puppet::Parser::AST::Selector.new :param => @param, :values => @values
      @selector.stubs(:fail)
    end

    it "should evaluate param" do
      @param.expects(:safeevaluate).with(@scope)

      @selector.evaluate(@scope)
    end

    it "should scan each option" do
      @values.expects(:each).multiple_yields(@value1, @value2)

      @selector.evaluate(@scope)
    end

    describe "when scanning values" do
      it "should evaluate first matching option" do
        @param2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @value2.expects(:safeevaluate).with(@scope)

        @selector.evaluate(@scope)
      end

      it "should return the first matching evaluated option" do
        @param2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @value2.stubs(:safeevaluate).with(@scope).returns(:result)

        @selector.evaluate(@scope).should == :result
      end

      it "should evaluate the default option if none matched" do
        @param1.stubs(:is_a?).with(Puppet::Parser::AST::Default).returns(true)
        @value1.expects(:safeevaluate).with(@scope).returns(@param1)

        @selector.evaluate(@scope)
      end

      it "should return the default evaluated option if none matched" do
        result = stub 'result'
        @param1.stubs(:is_a?).with(Puppet::Parser::AST::Default).returns(true)
        @value1.stubs(:safeevaluate).returns(result)

        @selector.evaluate(@scope).should == result
      end

      it "should return nil if nothing matched" do
        @selector.evaluate(@scope).should be_nil
      end

      it "should delegate matching to evaluate_match" do
        @param1.expects(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }

        @selector.evaluate(@scope)
      end

      it "should evaluate the matching param" do
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)

        @value1.expects(:safeevaluate).with(@scope)

        @selector.evaluate(@scope)
      end

      it "should return this evaluated option if it matches" do
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:safeevaluate).with(@scope).returns(:result)

        @selector.evaluate(@scope).should == :result
      end

      it "should unset scope ephemeral variables after option evaluation" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:safeevaluate).with(@scope).returns(:result)

        @scope.expects(:unset_ephemeral_var).with(:level)

        @selector.evaluate(@scope)
      end

      it "should not leak ephemeral variables even if evaluation fails" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @param1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @value1.stubs(:safeevaluate).with(@scope).raises

        @scope.expects(:unset_ephemeral_var).with(:level)

        lambda { @selector.evaluate(@scope) }.should raise_error
      end

      it "should fail if there is no default" do
        @selector.expects(:fail)

        @selector.evaluate(@scope)
      end
    end
  end
  describe "when converting to string" do
    it "should produce a string version of this selector" do
      values = Puppet::Parser::AST::ASTArray.new :children => [ Puppet::Parser::AST::ResourceParam.new(:param => "type", :value => "value", :add => false) ]
      param = Puppet::Parser::AST::Variable.new :value => "myvar"
      selector = Puppet::Parser::AST::Selector.new :param => param, :values => values
      selector.to_s.should == "$myvar ? { type => value }"
    end
  end
end
