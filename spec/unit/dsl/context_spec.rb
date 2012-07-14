require 'spec_helper'
require 'puppet_spec/dsl'

require 'puppet/dsl/parser'
require 'puppet/dsl/context'

include PuppetSpec::DSL

describe Puppet::DSL::Context do

  before :each do
    prepare_compiler_and_scope
  end

  context "when creating resources" do

    it "should raise a NoMethodError when trying to create a resoruce with invalid type" do
      lambda do
        evaluate_in_context do
          create_resource :foobar, "test"
        end
      end.should raise_error NoMethodError
    end

    it "should return an array of created resources" do
      evaluate_in_context do
        create_resource :file, "/tmp/test"
      end.each do |r|
        r.should be_a Puppet::Parser::Resource
      end
    end

    it "should set proper title" do
      title = "/tmp/test"
      evaluate_in_context do
        create_resource :file, title
      end.first.title.should == title
    end

    it "should set resource parameters" do
      parameters = {:ensure => :present, :mode => "0666"}
      res = evaluate_in_context do
        create_resource :file, "/tmp/test", parameters
      end.first

      parameters.each do |k, v|
        res[k].should == v
      end
    end

    it "should allow block syntax for creating resources" do
      res = evaluate_in_context do
        create_resource :file, "/tmp/test" do |r|
          r.ensure = :present
          r.mode   = "0666"
        end
      end.first

      res[:ensure].should == :present
      res[:mode].should == "0666"
    end

    it "should allow both block and a hash; block overwrites hash" do
      res = evaluate_in_context do
        create_resource :file, "/tmp/test", :mode => "0600" do |r|
          r.mode   = "0666"
        end
      end.first[:mode].should == "0666"
    end

    it "should work with method_missing" do
      evaluate_in_context do
        file("/tmp/test")
      end
    end

    it "should mark resource as virtual when virtualizing? is set" do
      evaluate_in_context do
        virtual do
          create_resource :notify, "foo"
        end
      end.first.virtual.should be true
    end

    it "should mark resource as exported when exporting? is set" do
      evaluate_in_context do
        export do
          create_resource :notify, "foo"
        end
      end.first.exported.should be true
    end

    it "should mark resource as exported when options[:export] is set" do
      evaluate_in_context do
        create_resource :notify, "foo", :export => true
      end.first.exported.should be true
    end

  end

  context "when calling a function" do
    it "should check whether the function is valid" do
      Puppet::Parser::Functions.expects(:function).
                                at_least_once.
                                with(:notice).
                                returns true

      evaluate_in_context do
        call_function :notice, "foo"
      end
    end

    it "should raise NoMethodError if the function is invalid" do
      lambda do
        evaluate_in_context do
          call_function :foobar
        end
      end.should raise_error NoMethodError
    end

    it "should call function with passed arguments" do
      Puppet::Parser::Functions.stubs(:function).returns true
      @scope.expects(:foobar).with [1, 2, 3]
      evaluate_in_context do
        call_function :foobar, 1, 2, 3
      end
    end

    it "should work with method_missing" do
      @scope.expects :notice
      evaluate_in_context do
        notice
      end
    end

  end

  context "with method missing" do

    it "should create a resource" do
      resources = nil
      evaluate_in_context do
        resources = file "/tmp/test", :ensure => :present
      end

      resources.should be_an Array
      resources.each do |r|
        r.should be_a Puppet::Parser::Resource
        r[:ensure].should == :present
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
        r[:ensure].should == :present
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

  context "when creating definition" do

    it "should add a new type" do
      evaluate_in_context do
        define(:foo) {}
      end.should == known_resource_types.definition(:foo)
    end

    it "should evaluate the block"

    it "should return Puppet::Resource::Type" do
      evaluate_in_context do
        define(:foo) {}
      end.should be_a Puppet::Resource::Type
    end

    it "should create a definition" do
      evaluate_in_context do
        define(:foo) {}
      end.type.should == :definition
    end

    it "should set proper name" do
      evaluate_in_context do
        define(:foo) {}
      end.name.should == "foo"
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

    it "should assign arguments"

    it "should fail when passing invalid options"

  end

  context "when creating a node" do

    it "should add a new type" do
      evaluate_in_context do
        node("foo") {}
      end.should == known_resource_types.node(:foo)
    end

    it "should set proper title"

    it "should return Puppet::Resource::Type"

    it "should evaluate the block"

    it "should raise NoMethodError when the nesting is invalid" do
      Puppet::DSL::Parser.stubs(:valid_nesting?).returns false

      lambda do
        evaluate_in_context do
          node("foo") {}
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

    it "should assign a parent"

    it "should fail when passing invalid options"
  end

  describe "when creating a class" do

    it "should add a new type" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.should == known_resource_types.hostclass(:foo)
    end
 
    it "should return Puppet::Resource::Type object" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.should be_a Puppet::Resource::Type
    end

    it "should set proper name" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.name.should == "foo"
    end

    it "should create a hostclass" do
      evaluate_in_context do
        hostclass(:foo) {}
      end.type.should == :hostclass
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

    it "should set arguments" do
      args = {"myparam" => "foo"}
      evaluate_in_context do
        hostclass(:foo, :arguments => args) {}
      end.arguments.should == args
    end

    it "should set parent type" do
      parent = "parent"
      evaluate_in_context do
        hostclass(:foo, :inherits => parent) {}
      end.parent.should == parent
    end

    it "should fail when passing invalid options"
  end

  context "when referencing type" do
    it "should return a type reference when accessing constant" do
      evaluate_in_context do
        # Full name needs to be used to trigger const_missing
        Puppet::DSL::Context::Notify
      end.should be_a Puppet::DSL::TypeReference
    end

    it "should return a type reference using `type' method" do
      evaluate_in_context do
        type "notify"
      end.should be_a Puppet::DSL::TypeReference
    end

    it "should raise NameError when there is no valid type" do
      lambda do
        evaluate_in_context do
          Puppet::DSL::Context::Foobar
        end
      end.should raise_error NameError
    end

    it "should return type reference for a given type" do
      evaluate_in_context do
        Puppet::DSL::Context::Notify
      end.type.should == "Notify"
    end
  end

  describe "utility methods" do

    describe "#require" do
      it "should proxy require to Object" do
        Object.expects(:require).with "asdf"
        evaluate_in_context do
          require "asdf"
        end
      end
    end

    describe "#raise" do
      it "should proxy raise to Object" do
        Object.expects :raise
        evaluate_in_context do
          raise
        end
      end
    end

    describe "#params" do
      it "should return current scope" do
        evaluate_in_context do
          params.should == Puppet::DSL::Parser.current_scope
        end
      end
    end

    describe "#exporting?" do
      it "should return true when called from the export block" do
        evaluate_in_context do
          export do
            exporting?.should == true
          end
        end
      end

      it "should return false when called outside export block" do
        evaluate_in_context do
          exporting?.should == false
        end
      end
    end

    describe "#virtualizing?" do
      it "should return true when called from the virtual block" do
        evaluate_in_context do
          virtual do
            virtualizing?.should == true
          end
        end
      end

      it "should return false when called outside virtual block" do
        evaluate_in_context do
          virtualizing?.should == false
        end
      end
    end

    describe "#export"

    describe "#virtual"

    describe "#respond_to?"

    describe "#valid_function?"

    describe "#valid_type?"

    describe "#use"

    describe "#my"

  end

end

