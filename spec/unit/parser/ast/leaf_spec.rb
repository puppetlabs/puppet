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

describe Puppet::Parser::AST::FlatString do
  describe "when converting to string" do
    it "should transform its value to a quoted string" do
      Puppet::Parser::AST::FlatString.new(:value => 'ab').to_s.should == "\"ab\""
    end

    it "should escape embedded double-quotes" do
      value = Puppet::Parser::AST::FlatString.new(:value => 'hello "friend"')
      value.to_s.should == "\"hello \\\"friend\\\"\""
    end
  end
end

describe Puppet::Parser::AST::String do
  describe "when converting to string" do
    it "should transform its value to a quoted string" do
      Puppet::Parser::AST::String.new(:value => 'ab').to_s.should == "\"ab\""
    end

    it "should escape embedded double-quotes" do
      value = Puppet::Parser::AST::String.new(:value => 'hello "friend"')
      value.to_s.should == "\"hello \\\"friend\\\"\""
    end

    it "should return a dup of its value" do
      value = ""
      Puppet::Parser::AST::String.new( :value => value ).evaluate(stub('scope')).should_not be_equal(value)
    end
  end
end

describe Puppet::Parser::AST::Concat do
  describe "when evaluating" do
    before :each do
      node     = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      @scope   = Puppet::Parser::Scope.new(compiler)
    end

    it "should interpolate variables and concatenate their values" do
      one = Puppet::Parser::AST::String.new(:value => "one")
      one.stubs(:evaluate).returns("one ")
      two = Puppet::Parser::AST::String.new(:value => "two")
      two.stubs(:evaluate).returns(" two ")
      three = Puppet::Parser::AST::String.new(:value => "three")
      three.stubs(:evaluate).returns(" three")
      var = Puppet::Parser::AST::Variable.new(:value => "myvar")
      var.stubs(:evaluate).returns("foo")
      array = Puppet::Parser::AST::Variable.new(:value => "array")
      array.stubs(:evaluate).returns(["bar","baz"])
      concat = Puppet::Parser::AST::Concat.new(:value => [one,var,two,array,three])

      concat.evaluate(@scope).should == 'one foo two barbaz three'
    end

    it "should transform undef variables to empty string" do
      var = Puppet::Parser::AST::Variable.new(:value => "myvar")
      var.stubs(:evaluate).returns(:undef)
      concat = Puppet::Parser::AST::Concat.new(:value => [var])

      concat.evaluate(@scope).should == ''
    end
  end
end

describe Puppet::Parser::AST::Undef do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
    @undef   = Puppet::Parser::AST::Undef.new(:value => :undef)
  end

  it "should match undef with undef" do
    @undef.evaluate_match(:undef, @scope).should be_true
  end

  it "should not match undef with an empty string" do
    @undef.evaluate_match("", @scope).should be_true
  end
end

describe Puppet::Parser::AST::HashOrArrayAccess do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  describe "when evaluating" do
    it "should evaluate the variable part if necessary" do
      @scope["a"] = ["b"]

      variable = stub 'variable', :evaluate => "a"
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => variable, :key => 0 )

      variable.expects(:safeevaluate).with(@scope).returns("a")

      access.evaluate(@scope).should == "b"
    end

    it "should evaluate the access key part if necessary" do
      @scope["a"] = ["b"]

      index = stub 'index', :evaluate => 0
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => index )

      index.expects(:safeevaluate).with(@scope).returns(0)

      access.evaluate(@scope).should == "b"
    end

    it "should be able to return an array member" do
      @scope["a"] = %w{val1 val2 val3}

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => 1 )

      access.evaluate(@scope).should == "val2"
    end

    it "should be able to return an array member when index is a stringified number" do
      @scope["a"] = %w{val1 val2 val3}

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "1" )

      access.evaluate(@scope).should == "val2"
    end

    it "should raise an error when accessing an array with a key" do
      @scope["a"] = ["val1", "val2", "val3"]

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "get_me_the_second_element_please" )

      lambda { access.evaluate(@scope) }.should raise_error
    end

    it "should be able to return :undef for an unknown array index" do
      @scope["a"] = ["val1", "val2", "val3"]

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => 6 )

      access.evaluate(@scope).should == :undef
    end

    it "should be able to return a hash value" do
      @scope["a"] = { "key1" => "val1", "key2" => "val2", "key3" => "val3" }

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

      access.evaluate(@scope).should == "val2"
    end

    it "should be able to return :undef for unknown hash keys" do
      @scope["a"] = { "key1" => "val1", "key2" => "val2", "key3" => "val3" }

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key12" )

      access.evaluate(@scope).should == :undef
    end

    it "should be able to return a hash value with a numerical key" do
      @scope["a"] = { "key1" => "val1", "key2" => "val2", "45" => "45", "key3" => "val3" }

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "45" )

      access.evaluate(@scope).should == "45"
    end

    it "should raise an error if the variable lookup didn't return a hash or an array" do
      @scope["a"] = "I'm a string"

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

      lambda { access.evaluate(@scope) }.should raise_error
    end

    it "should raise an error if the variable wasn't in the scope" do
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

      lambda { access.evaluate(@scope) }.should raise_error
    end

    it "should return a correct string representation" do
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )
      access.to_s.should == '$a[key2]'
    end

    it "should work with recursive hash access" do
      @scope["a"] = { "key" => { "subkey" => "b" }}

      access1 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")
      access2 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => access1, :key => "subkey")

      access2.evaluate(@scope).should == 'b'
    end

    it "should work with interleaved array and hash access" do
      @scope['a'] = { "key" => [ "a" , "b" ]}

      access1 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")
      access2 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => access1, :key => 1)

      access2.evaluate(@scope).should == 'b'
    end

    it "should raise a useful error for hash access on undef" do
      @scope["a"] = :undef

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")

      expect {
        access.evaluate(@scope)
      }.to raise_error(Puppet::ParseError, /not a hash or array/)
    end

    it "should raise a useful error for hash access on TrueClass" do
      @scope["a"] = true

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")

      expect {
        access.evaluate(@scope)
      }.to raise_error(Puppet::ParseError, /not a hash or array/)
    end

    it "should raise a useful error for recursive undef hash access" do
      @scope["a"] = { "key" => "val" }

      access1 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "nonexistent")
      access2 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => access1, :key => "subkey")

      expect {
        access2.evaluate(@scope)
      }.to raise_error(Puppet::ParseError, /not a hash or array/)
    end

    it "should produce boolean values when value is a boolean" do
      @scope["a"] = [true, false]
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => 0 )
      expect(access.evaluate(@scope)).to be == true
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => 1 )
      expect(access.evaluate(@scope)).to be == false
    end
  end

  describe "when assigning" do
    it "should add a new key and value" do
      Puppet.expects(:warning).once
      node     = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      scope    = Puppet::Parser::Scope.new(compiler)

      scope['a'] = { 'a' => 'b' }

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "b")
      access.assign(scope, "c" )

      scope['a'].should be_include("b")
    end

    it "should raise an error when assigning an array element with a key" do
      @scope['a'] = []

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "get_me_the_second_element_please" )

      lambda { access.assign(@scope, "test") }.should raise_error
    end

    it "should be able to return an array member when index is a stringified number" do
      Puppet.expects(:warning).once
      node     = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      scope    = Puppet::Parser::Scope.new(compiler)

      scope['a'] = []

      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "0" )

      access.assign(scope, "val2")
      scope['a'].should == ["val2"]
    end

    it "should raise an error when trying to overwrite a hash value" do
      @scope['a'] = { "key" => [ "a" , "b" ]}
      access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")

      lambda { access.assign(@scope, "test") }.should raise_error
    end
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

    it "should not downcase the paramater value" do
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

describe Puppet::Parser::AST::Variable do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope = Puppet::Parser::Scope.new(compiler)
    @var = Puppet::Parser::AST::Variable.new(:value => "myvar", :file => 'my.pp', :line => 222)
  end

  it "should lookup the variable in scope" do
    @scope["myvar"] = :myvalue
    @var.safeevaluate(@scope).should == :myvalue
  end

  it "should pass the source location to lookupvar" do
    @scope.setvar("myvar", :myvalue, :file => 'my.pp', :line => 222 )
    @var.safeevaluate(@scope).should == :myvalue
  end

  it "should return undef if the variable wasn't set" do
    @var.safeevaluate(@scope).should == :undef
  end

  describe "when converting to string" do
    it "should transform its value to a variable" do
      value = stub 'value', :is_a? => true, :to_s => "myvar"
      Puppet::Parser::AST::Variable.new( :value => value ).to_s.should == "\$myvar"
    end
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
