#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Leaf do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @value = stub 'value'
    @leaf = Puppet::Parser::AST::Leaf.new(:value => @value)
  end

  it "should have an evaluate_match method" do
    Puppet::Parser::AST::Leaf.new(:value => "value").should respond_to(:evaluate_match)
  end

  describe "when converting to string" do
    it "should transform its value to string" do
      value = stub 'value', :is_a? => true
      value.expects(:to_s)
      Puppet::Parser::AST::Leaf.new( :value => value ).to_s
    end
  end

  it "should have a match method" do
    @leaf.should respond_to(:match)
  end

  it "should delegate match to ==" do
    @value.expects(:==).with("value")

    @leaf.match("value")
  end
end


describe Puppet::Parser::AST::Regex do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  describe "when initializing" do
    it "should create a Regexp with its content when value is not a Regexp" do
      Regexp.expects(:new).with("/ab/")

      Puppet::Parser::AST::Regex.new :value => "/ab/"
    end

    it "should not create a Regexp with its content when value is a Regexp" do
      value = Regexp.new("/ab/")
      Regexp.expects(:new).with("/ab/").never

      Puppet::Parser::AST::Regex.new :value => value
    end
  end

  describe "when evaluating" do
    it "should return self" do
      val = Puppet::Parser::AST::Regex.new :value => "/ab/"

      val.evaluate(@scope).should === val
    end
  end

  describe "when evaluate_match" do
    before :each do
      @value = stub 'regex'
      @value.stubs(:match).with("value").returns(true)
      Regexp.stubs(:new).returns(@value)
      @regex = Puppet::Parser::AST::Regex.new :value => "/ab/"
    end

    it "should issue the regexp match" do
      @value.expects(:match).with("value")

      @regex.evaluate_match("value", @scope)
    end

    it "should not downcase the parameter value" do
      @value.expects(:match).with("VaLuE")

      @regex.evaluate_match("VaLuE", @scope)
    end

    it "should set ephemeral scope vars if there is a match" do
      @scope.expects(:ephemeral_from).with(true, nil, nil)

      @regex.evaluate_match("value", @scope)
    end

    it "should return the match to the caller" do
      @value.stubs(:match).with("value").returns(:match)
      @scope.stubs(:ephemeral_from)

      @regex.evaluate_match("value", @scope)
    end
  end

  it "should match undef to the empty string" do
    regex = Puppet::Parser::AST::Regex.new(:value => "^$")
    regex.evaluate_match(:undef, @scope).should be_true
  end

  it "should not match undef to a non-empty string" do
    regex = Puppet::Parser::AST::Regex.new(:value => '\w')
    regex.evaluate_match(:undef, @scope).should be_false
  end

  it "should match a string against a string" do
    regex = Puppet::Parser::AST::Regex.new(:value => '\w')
    regex.evaluate_match('foo', @scope).should be_true
  end

  it "should return the regex source with to_s" do
    regex = stub 'regex'
    Regexp.stubs(:new).returns(regex)

    val = Puppet::Parser::AST::Regex.new :value => "/ab/"

    regex.expects(:source)

    val.to_s
  end

  it "should delegate match to the underlying regexp match method" do
    regex = Regexp.new("/ab/")
    val = Puppet::Parser::AST::Regex.new :value => regex

    regex.expects(:match).with("value")

    val.match("value")
  end
end

describe Puppet::Parser::AST::HostName do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @value   = 'value'
    @value.stubs(:to_s).returns(@value)
    @value.stubs(:downcase).returns(@value)
    @host = Puppet::Parser::AST::HostName.new(:value => @value)
  end

  it "should raise an error if hostname is not valid" do
    lambda { Puppet::Parser::AST::HostName.new( :value => "not a hostname!" ) }.should raise_error
  end

  it "should not raise an error if hostname is a regex" do
    lambda { Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/test/") ) }.should_not raise_error
  end

  it "should stringify the value" do
    value = stub 'value', :=~ => false

    value.expects(:to_s).returns("test")

    Puppet::Parser::AST::HostName.new(:value => value)
  end

  it "should downcase the value" do
    value = stub 'value', :=~ => false
    value.stubs(:to_s).returns("UPCASED")
    host = Puppet::Parser::AST::HostName.new(:value => value)

    host.value == "upcased"
  end

  it "should evaluate to its value" do
    @host.evaluate(@scope).should == @value
  end

  it "should delegate eql? to the underlying value if it is an HostName" do
    @value.expects(:eql?).with("value")
    @host.eql?("value")
  end

  it "should delegate eql? to the underlying value if it is not an HostName" do
    value = stub 'compared', :is_a? => true, :value => "value"
    @value.expects(:eql?).with("value")
    @host.eql?(value)
  end

  it "should delegate hash to the underlying value" do
    @value.expects(:hash)
    @host.hash
  end
end
