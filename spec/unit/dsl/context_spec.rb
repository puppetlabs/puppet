require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/parser'
require 'puppet/dsl/context'

include PuppetSpec::DSL

describe Puppet::DSL::Context do

  before :each do
    @compiler = Puppet::Parser::Compiler.new Puppet::Node.new("test")
    @scope = Puppet::Parser::Scope.new :compiler => @compiler, :source => "test"
  end

  describe "when creating resources" do

    it "should raise a NoMethodError when trying to create a resoruce with invalid type" do
      lambda do
        evaluate_in_context do
          create_resource :foobar, "test"
        end
      end.should raise_error NoMethodError
    end

    it "should return an array of created resources" do
      resources = nil
      evaluate_in_context do
        resources = create_resource :file, "/tmp/test", "/tmp/foobar", :ensure => :present
      end

      resources.should be_an Array
      resources.each do |r|
        r.should be_a Puppet::Parser::Resource
      end
    end

  end

  describe "when calling a function" do

    it "should check whether the function is valid" do
      Puppet::Parser::Functions.expects(:function).
                                at_least_once.
                                with(:notice).
                                returns true

      evaluate_in_context do
        notice "foo"
      end

    end

    it "should raise NoMethodError if the function is invalid" do
      lambda do
        evaluate_in_context do
          call_function :foobar
        end
      end.should raise_error NoMethodError
    end

  end

  describe "with method missing" do

    it "should create a resource" do
      resources = nil
      evaluate_in_context do
        resources = file "/tmp/test", :ensure => :present
      end

      resources.should be_an Array
      resources.each do |r|
        r.should be_a Puppet::Parser::Resource
        r[:ensure].should == "present"
      end
    end

    it "should allow to use block syntax to create a resource" do
      resources = nil
      evaluate_in_context do
        resources = file "/tmp/test" do |f|
          f.ensure = :present
        end
      end

      resources.should be_an Array
      resources.each do |r|
        r.should be_a Puppet::Parser::Resource
        r[:ensure].should == "present"
      end
    end

    it "should call a function" do
      @scope.expects(:send).with(:notice, ["foo"])
      evaluate_in_context do
        notice "foo"
      end
    end


    it "should raise NoMethodError when neither function nor resource type exists" do
      lambda do
        evaluate_in_context do
          self.foobar
        end
      end.should raise_error NoMethodError
    end

  end

  describe "when creating definition" do

    it "should add a new type" do
      result = nil
      evaluate_in_context do
        result = define(:foo) {}
      end

      result.should be_a Puppet::Resource::Type
      result.type.should be_equal :definition
      result.name.should == "foo"

      known_resource_types.definition(:foo).should == result
    end

    it "should raise NoMethodError when the nesting is invalid" do
      Puppet::DSL::Parser.stubs(:valid_nesting?).returns false

      lambda do
        evaluate_in_context do
          define(:foo) {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        evaluate_in_context do
          define :foo
        end
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments

  end

  describe "when creating a node" do

    it "should add a new type" do
      n = nil
      evaluate_in_context do
        n = node(:foo) {}

      end

      n.should be_a Puppet::Resource::Type
      n.type.should be_equal :node
      n.name.should == "foo"

      known_resource_types.node(:foo).should == n
    end

    it "should raise NoMethodError when the nesting is invalid" do
      Puppet::DSL::Parser.stubs(:valid_nesting?).returns false

      lambda do
        evaluate_in_context do
          node(:foo) {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when there is no block given" do
      lambda do
        evaluate_in_context do
          node :foo
        end
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments and inheritance

  end

  describe "when creating a class" do

    it "should add a new type" do
      h = nil
      evaluate_in_context do
        h = hostclass(:foo) {}
      end

      h.should be_a Puppet::Resource::Type
      h.type.should be_equal :hostclass
      h.name.should == "foo"

      known_resource_types.hostclass(:foo).should == h
    end

    it "should raise NoMethodError when called in invalid nesting" do
      Puppet::DSL::Parser.stubs(:valid_nesting?).returns false

      lambda do
        evaluate_in_context do
          hostclass(:foo) {}
        end
      end.should raise_error NoMethodError
    end

    it "should raise ArgumentError when no block is given" do
      lambda do
        evaluate_in_context do
          hostclass :foo
        end
      end.should raise_error ArgumentError
    end

    # MLEN:TODO: add tests for arguments and inheritance
  end

end

