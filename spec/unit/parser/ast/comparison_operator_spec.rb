#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::ComparisonOperator do
  before :each do
    @scope = Puppet::Parser::Scope.new
    @one = Puppet::Parser::AST::Leaf.new(:value => "1")
    @two = Puppet::Parser::AST::Leaf.new(:value => "2")

    @lval = Puppet::Parser::AST::Leaf.new(:value => "one")
    @rval = Puppet::Parser::AST::Leaf.new(:value => "two")
  end

  it "should evaluate both values" do
    @lval.expects(:safeevaluate).with(@scope)
    @rval.expects(:safeevaluate).with(@scope)

    operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @lval, :operator => "==", :rval => @rval
    operator.evaluate(@scope)
  end

  it "should convert the arguments to numbers if they are numbers in string" do
    Puppet::Parser::Scope.expects(:number?).with("1").returns(1)
    Puppet::Parser::Scope.expects(:number?).with("2").returns(2)

    operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => "==", :rval => @two
    operator.evaluate(@scope)
  end

  %w{< > <= >=}.each do |oper|
    it "should use string comparison #{oper} if operands are strings" do
      operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @lval, :operator => oper, :rval => @rval
      operator.evaluate(@scope).should == "one".send(oper,"two")
    end
  end

  describe "with string comparison" do
    it "should use matching" do
      @rval.expects(:evaluate_match).with("one", @scope)

      operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @lval, :operator => "==", :rval => @rval
      operator.evaluate(@scope)
    end

    it "should return true for :undef to '' equality" do
      astundef = Puppet::Parser::AST::Leaf.new(:value => :undef)
      empty = Puppet::Parser::AST::Leaf.new(:value => '')

      operator = Puppet::Parser::AST::ComparisonOperator.new :lval => astundef, :operator => "==", :rval => empty
      operator.evaluate(@scope).should be_true
    end

    [true, false].each do |result|
      it "should return #{(result).inspect} with '==' when matching return #{result.inspect}" do
        @rval.expects(:evaluate_match).with("one", @scope).returns result

        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @lval, :operator => "==", :rval => @rval
        operator.evaluate(@scope).should == result
      end

      it "should return #{(!result).inspect} with '!=' when matching return #{result.inspect}" do
        @rval.expects(:evaluate_match).with("one", @scope).returns result

        operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @lval, :operator => "!=", :rval => @rval
        operator.evaluate(@scope).should == !result
      end
    end
  end

  it "should fail with arguments of different types" do
    operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => ">", :rval => @rval
    lambda { operator.evaluate(@scope) }.should raise_error(ArgumentError)
  end

  it "should fail for an unknown operator" do
    lambda { operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => "or", :rval => @two }.should raise_error
  end

  %w{< > <= >= ==}.each do |oper|
    it "should return the result of using '#{oper}' to compare the left and right sides" do
      operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => oper, :rval => @two

      operator.evaluate(@scope).should == 1.send(oper,2)
    end
  end

  it "should return the result of using '!=' to compare the left and right sides" do
    operator = Puppet::Parser::AST::ComparisonOperator.new :lval => @one, :operator => '!=', :rval => @two

    operator.evaluate(@scope).should == true
  end

  it "should work for variables too" do
    one = Puppet::Parser::AST::Variable.new( :value => "one" )
    two = Puppet::Parser::AST::Variable.new( :value => "two" )

    one.expects(:safeevaluate).with(@scope).returns(1)
    two.expects(:safeevaluate).with(@scope).returns(2)

    operator = Puppet::Parser::AST::ComparisonOperator.new :lval => one, :operator => "<", :rval => two
    operator.evaluate(@scope).should == true
  end

  # see ticket #1759
  %w{< > <= >=}.each do |oper|
    it "should return the correct result of using '#{oper}' to compare 10 and 9" do
      ten = Puppet::Parser::AST::Leaf.new(:value => "10")
      nine = Puppet::Parser::AST::Leaf.new(:value => "9")
      operator = Puppet::Parser::AST::ComparisonOperator.new :lval => ten, :operator => oper, :rval => nine

      operator.evaluate(@scope).should == 10.send(oper,9)
    end
  end

end
