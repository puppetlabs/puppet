#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ArithmeticOperator do

  ast = Puppet::Parser::AST

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @one = stub 'lval', :safeevaluate => 1
    @two = stub 'rval', :safeevaluate => 2
  end

  it "should evaluate both branches" do
    lval = stub "lval"
    lval.expects(:safeevaluate).with(@scope).returns(1)
    rval = stub "rval"
    rval.expects(:safeevaluate).with(@scope).returns(2)

    operator = ast::ArithmeticOperator.new :rval => rval, :operator => "+", :lval => lval
    operator.evaluate(@scope)
  end

  it "should fail for an unknown operator" do
    lambda { operator = ast::ArithmeticOperator.new :lval => @one, :operator => "^", :rval => @two }.should raise_error
  end

  it "should call Puppet::Parser::Scope.number?" do
    Puppet::Parser::Scope.expects(:number?).with(1).returns(1)
    Puppet::Parser::Scope.expects(:number?).with(2).returns(2)

    ast::ArithmeticOperator.new(:lval => @one, :operator => "+", :rval => @two).evaluate(@scope)
  end


  %w{ + - * / % << >>}.each do |op|
    it "should call ruby Numeric '#{op}'" do
      one = stub 'one'
      two = stub 'two'
      operator = ast::ArithmeticOperator.new :lval => @one, :operator => op, :rval => @two
      Puppet::Parser::Scope.stubs(:number?).with(1).returns(one)
      Puppet::Parser::Scope.stubs(:number?).with(2).returns(two)
      one.expects(:send).with(op,two)
      operator.evaluate(@scope)
    end
  end

  it "should work even with numbers embedded in strings" do
    two = stub 'two', :safeevaluate => "2"
    one = stub 'one', :safeevaluate => "1"
    operator = ast::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
    operator.evaluate(@scope).should == 3
  end

  it "should work even with floats" do
    two = stub 'two', :safeevaluate => 2.53
    one = stub 'one', :safeevaluate => 1.80
    operator = ast::ArithmeticOperator.new :lval => two, :operator => "+", :rval => one
    operator.evaluate(@scope).should == 4.33
  end

  context "when applied to array" do
    before :each do
      Puppet[:parser] = 'future'
    end

    it "+ should concatenate an array" do
      one = stub 'one', :safeevaluate => [1,2,3]
      two = stub 'two', :safeevaluate => [4,5]
      operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
      operator.evaluate(@scope).should == [1,2,3,4,5]
    end

    it "<< should append array to an array" do
      one = stub 'one', :safeevaluate => [1,2,3]
      two = stub 'two', :safeevaluate => [4,5]
      operator = ast::ArithmeticOperator.new :lval => one, :operator => "<<", :rval => two
      operator.evaluate(@scope).should == [1,2,3, [4,5]]
    end

    it "<< should append object to an array" do
      one = stub 'one', :safeevaluate => [1,2,3]
      two = stub 'two', :safeevaluate => 'a b c'
      operator = ast::ArithmeticOperator.new :lval => one, :operator => "<<", :rval => two
      operator.evaluate(@scope).should == [1,2,3, 'a b c']
    end

    context "and input is invalid" do
      it "should raise error for + if left is not an array" do
        one = stub 'one', :safeevaluate => 4
        two = stub 'two', :safeevaluate => [4,5]
        operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
        lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error(/left/)
      end

      it "should raise error for << if left is not an array" do
        one = stub 'one', :safeevaluate => 4
        two = stub 'two', :safeevaluate => [4,5]
        operator = ast::ArithmeticOperator.new :lval => one, :operator => "<<", :rval => two
        lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error(/left/)
      end

      it "should raise error for + if right is not an array" do
        one = stub 'one', :safeevaluate => [1,2]
        two = stub 'two', :safeevaluate => 45
        operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
        lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error(/right/)
      end

      %w{ - * / % >>}.each do |op|
        it "should raise error for '#{op}'" do
          one = stub 'one', :safeevaluate => [1,2,3]
          two = stub 'two', :safeevaluate => [4,5]
          operator = ast::ArithmeticOperator.new :lval => @one, :operator => op, :rval => @two
          lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error
        end
      end
    end

    context "when applied to hash" do
      before :each do
        Puppet[:parser] = 'future'
      end

      it "+ should merge two hashes" do
        one = stub 'one', :safeevaluate => {'a' => 1, 'b' => 2}
        two = stub 'two', :safeevaluate => {'c' => 3 }
        operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
        operator.evaluate(@scope).should == {'a' => 1, 'b' => 2, 'c' => 3}
      end

      context "and input is invalid" do
        it "should raise error for + if left is not a hash" do
          one = stub 'one', :safeevaluate => 4
          two = stub 'two', :safeevaluate => {'a' => 1}
          operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
          lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error(/left/)
        end

        it "should raise error for + if right is not a hash" do
          one = stub 'one', :safeevaluate => {'a' => 1}
          two = stub 'two', :safeevaluate => 1
          operator = ast::ArithmeticOperator.new :lval => one, :operator => "+", :rval => two
          lambda { operator.evaluate(@scope).should == {'a'=>1, 1=>nil} }.should raise_error(/right/)
        end

        %w{ - * / % << >>}.each do |op|
          it "should raise error for '#{op}'" do
            one = stub 'one', :safeevaluate => {'a' => 1, 'b' => 2}
            two = stub 'two', :safeevaluate => {'c' => 3 }
            operator = ast::ArithmeticOperator.new :lval => @one, :operator => op, :rval => @two
            lambda { operator.evaluate(@scope).should == [1,2,3,4,5] }.should raise_error
          end
        end
      end
    end
  end
end
