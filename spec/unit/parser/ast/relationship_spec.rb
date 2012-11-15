#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Relationship do
  before do
    @class = Puppet::Parser::AST::Relationship
  end

  it "should set its 'left' and 'right' arguments accordingly" do
    dep = @class.new(:left, :right, '->')
    dep.left.should == :left
    dep.right.should == :right
  end

  it "should set its arrow to whatever arrow is passed" do
    @class.new(:left, :right, '->').arrow.should == '->'
  end

  it "should set its type to :relationship if the relationship type is '<-'" do
    @class.new(:left, :right, '<-').type.should == :relationship
  end

  it "should set its type to :relationship if the relationship type is '->'" do
    @class.new(:left, :right, '->').type.should == :relationship
  end

  it "should set its type to :subscription if the relationship type is '~>'" do
    @class.new(:left, :right, '~>').type.should == :subscription
  end

  it "should set its type to :subscription if the relationship type is '<~'" do
    @class.new(:left, :right, '<~').type.should == :subscription
  end

  it "should set its line and file if provided" do
    dep = @class.new(:left, :right, '->', :line => 50, :file => "/foo")
    dep.line.should == 50
    dep.file.should == "/foo"
  end

  describe "when evaluating" do
    before do
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
      @scope = Puppet::Parser::Scope.new(@compiler)
    end

    it "should create a relationship with the evaluated source and target and add it to the scope" do
      source = stub 'source', :safeevaluate => :left
      target = stub 'target', :safeevaluate => :right
      @class.new(source, target, '->').evaluate(@scope)
      @compiler.relationships[0].source.should == :left
      @compiler.relationships[0].target.should == :right
    end

    describe "a chained relationship" do
      before do
        @left = stub 'left', :safeevaluate => :left
        @middle = stub 'middle', :safeevaluate => :middle
        @right = stub 'right', :safeevaluate => :right
        @first = @class.new(@left, @middle, '->')
        @second = @class.new(@first, @right, '->')
      end

      it "should evaluate the relationship to the left" do
        @first.expects(:evaluate).with(@scope).returns Puppet::Parser::Relationship.new(:left, :right, :relationship)

        @second.evaluate(@scope)
      end

      it "should use the right side of the left relationship as its source" do
        @second.evaluate(@scope)

        @compiler.relationships[0].source.should == :left
        @compiler.relationships[0].target.should == :middle
        @compiler.relationships[1].source.should == :middle
        @compiler.relationships[1].target.should == :right
      end

      it "should only evaluate a given AST node once" do
        @left.expects(:safeevaluate).once.returns :left
        @middle.expects(:safeevaluate).once.returns :middle
        @right.expects(:safeevaluate).once.returns :right
        @second.evaluate(@scope)
      end
    end
  end
end
