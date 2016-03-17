#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ASTHash do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should have a merge functionality" do
    hash = Puppet::Parser::AST::ASTHash.new(:value => {})
    hash.should respond_to(:merge)
  end

  it "should be able to merge 2 AST hashes" do
    hash = Puppet::Parser::AST::ASTHash.new(:value => { "a" => "b" })

    hash.merge(Puppet::Parser::AST::ASTHash.new(:value => {"c" => "d"}))

    hash.value.should == { "a" => "b", "c" => "d" }
  end

  it "should be able to merge with a ruby Hash" do
    hash = Puppet::Parser::AST::ASTHash.new(:value => { "a" => "b" })

    hash.merge({"c" => "d"})

    hash.value.should == { "a" => "b", "c" => "d" }
  end

  it "should evaluate each hash value" do
    key1 = stub "key1"
    value1 = stub "value1"
    key2 = stub "key2"
    value2 = stub "value2"

    value1.expects(:safeevaluate).with(@scope).returns("b")
    value2.expects(:safeevaluate).with(@scope).returns("d")

    operator = Puppet::Parser::AST::ASTHash.new(:value => { key1 => value1, key2 => value2})
    operator.evaluate(@scope)
  end

  it "should evaluate the hash keys if they are AST instances" do
    key1 = stub "key1"
    value1 = stub "value1", :safeevaluate => "one"
    key2 = stub "key2"
    value2 = stub "value2", :safeevaluate => "two"

    key1.expects(:safeevaluate).with(@scope).returns("1")
    key2.expects(:safeevaluate).with(@scope).returns("2")

    operator = Puppet::Parser::AST::ASTHash.new(:value => { key1 => value1, key2 => value2})
    hash = operator.evaluate(@scope)
    hash["1"].should == "one"
    hash["2"].should == "two"
  end

  it "should evaluate the hash keys if they are not AST instances" do
    key1 = "1"
    value1 = stub "value1", :safeevaluate => "one"
    key2 = "2"
    value2 = stub "value2", :safeevaluate => "two"

    operator = Puppet::Parser::AST::ASTHash.new(:value => { key1 => value1, key2 => value2})
    hash = operator.evaluate(@scope)
    hash["1"].should == "one"
    hash["2"].should == "two"
  end

  it "should return an evaluated hash" do
    key1 = stub "key1"
    value1 = stub "value1", :safeevaluate => "b"
    key2 = stub "key2"
    value2 = stub "value2", :safeevaluate => "d"

    operator = Puppet::Parser::AST::ASTHash.new(:value => { key1 => value1, key2 => value2})
    operator.evaluate(@scope).should == { key1 => "b", key2 => "d" }
  end

  describe "when being initialized without arguments" do
    it "should evaluate to an empty hash" do
      hash = Puppet::Parser::AST::ASTHash.new({})
      hash.evaluate(@scope).should == {}
    end

    it "should support merging" do
      hash = Puppet::Parser::AST::ASTHash.new({})
      hash.merge({"a" => "b"}).should == {"a" => "b"}
    end
  end

  it "should return a valid string with to_s" do
    hash = Puppet::Parser::AST::ASTHash.new(:value => { "a" => "b", "c" => "d" })
    ["{a => b, c => d}", "{c => d, a => b}"].should be_include hash.to_s
  end
end
