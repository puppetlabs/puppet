require 'spec_helper'

require 'puppet/dsl/context'

describe Puppet::DSL::Context do

  before :each do
    @compiler = Puppet::Parser::Compiler.new Puppet::Node.new("test")
    @scope = Puppet::Parser::Scope.new :compiler => @compiler, :source => "test"
    @context = Puppet::DSL::Context.new(proc {}).evaluate @scope
  end

  describe "when creating resources" do

    # MLEN:TODO: find a way to assert method call when using method_missing
    it "should check whether the resources have valid types"

    it "should raise a NoMethodError when trying to create a resoruce with invalid type" do
      lambda do
        @context.create_resource :foobar, "test"
      end.should raise_error NoMethodError
    end

    it "should return an array of created resources" do
      resources = @context.create_resource :file, "/tmp/test", "/tmp/foobar", :ensure => :present
      resources.should be_an Array
      resources.each do |r|
        r.should be_a Puppet::Parser::Resource
      end
    end

  end

  describe "when calling a function" do

    it "should check whether the function is valid"

    it "should raise NoMethodError if the function is invalid" do
      lambda do
        @context.call_function :foobar
      end.should raise_error NoMethodError
    end

  end

  describe "with method missing" do

    it "should create a resource"

    it "should call a function"

    it "should raise NoMethodError when neither function nor resource type exists" do
      lambda do
        @context.foobar
      end.should raise_error NoMethodError
    end

  end

  describe "when creating definition" do

    it "should add a new type" do
      result = @context.define(:foo) {}

      result.should be_a Puppet::Resource::Type
      result.type.should be_equal :definition
      result.name.should == "foo"

      @compiler.known_resource_types.definition(:foo).should == result
    end

    it "should raise NoMethodError when the nesting is invalid" do
      # new context with invalid nesting = 1
      context = Puppet::DSL::Context.new(proc {}, 1).evaluate @scope

      lambda do
        context.define(:foo) {}
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        @context.define :foo
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments

  end

  describe "when creating a node" do

    it "should add a new type" do
      node = @context.node(:foo) {}
      node.should be_a Puppet::Resource::Type
      node.type.should be_equal :node
      node.name.should == "foo"

      @compiler.known_resource_types.node(:foo).should == node
    end

    it "should raise NoMethodError when the nesting is invalid" do
      context = Puppet::DSL::Context.new(proc {}, 1).evaluate @scope

      lambda do
        context.node(:foo) {}
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when there is no block given" do
      lambda do
        @context.node :foo
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments and inheritance

  end

  describe "when creating a class" do

    it "should add a new type" do
      hostclass = @context.hostclass(:foo) {}

      hostclass.should be_a Puppet::Resource::Type
      hostclass.type.should be_equal :hostclass
      hostclass.name.should == "foo"

      @compiler.known_resource_types.hostclass(:foo).should == hostclass
    end

    it "should raise NoMethodError when called in invalid nesting" do
      context = Puppet::DSL::Context.new(proc {}, 1).evaluate @scope

      lambda do
        context.hostclass(:foo) {}
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        @context.hostclass :foo
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments and inheritance
  end

end

