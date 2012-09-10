require 'spec_helper'
require 'puppet_spec/dsl'
require 'puppet/dsl/resource_reference'

describe Puppet::DSL::ResourceReference do
  include PuppetSpec::DSL

  before :each do
    prepare_compiler_and_scope
    @typeref = Puppet::DSL::TypeReference.new "notify"
  end

  describe "#initialize" do

    it "should validate resource existance" do
      @scope.expects(:findresource).returns(!nil)
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new @typeref, "foo"
      end
    end

    it "should raise ArgumentError when resource doesn't exist" do
      @scope.expects(:findresource).returns nil
      evaluate_in_scope do
        lambda do
          Puppet::DSL::ResourceReference.new @typeref, "foo"
        end.should raise_error ArgumentError
      end
    end

  end

  describe "#reference" do
    before :each do
      evaluate_in_context { notify "foo" }
    end

    it "should return string reference of a resource" do
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foo").reference.should == "Notify[foo]"
      end
    end

    it "should be aliased to #to_s" do
      evaluate_in_scope do
        r = Puppet::DSL::ResourceReference.new(@typeref, "foo")
        r.reference.should == r.to_s
      end
    end

  end

  describe "#override" do
    before :each do
      evaluate_in_context { notify "foo" }
    end

    it "should create new resource override" do
      evaluate_in_scope do
        r = Puppet::DSL::ResourceReference.new @typeref, "foo"
        r.override :message => "asdf"
        r.resource[:message].should == "asdf"
      end
    end

    it "should return the override" do
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foo").
          override(:message => "bar").should == {:message => "bar"}
      end
    end

    it "should allow passing a hash" do
      evaluate_in_scope do
        lambda do
          Puppet::DSL::ResourceReference.new(@typeref, "foo").
            override(:message => "foobar").should == {:message => "foobar"}
        end.should_not raise_error
      end
    end

    it "should allow passing a block" do
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foo").override do |foo|
          foo.message = "foobarbaz"
        end.should == {:message => "foobarbaz"}
      end
    end

    it "should allow passing both block and a hash; block overwrites hash" do
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foo").
          override(:message => "foobar") do |foo|
          foo.message = "foobarbaz"
          end.should == {:message => "foobarbaz"}
      end
    end

    it "should raise ArgumentError when neither block or hash is passed" do
      evaluate_in_scope do
        lambda do
          Puppet::DSL::ResourceReference.new(@typeref, "foo").override
        end.should raise_error ArgumentError
      end

    end
  end

  describe "#realize" do

    it "realizes the resource if it was virtual" do
      evaluate_in_context { virtual notify "foobarbaz" }
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foobarbaz").realize
      end

      @scope.compiler.collections.map(&:resources).flatten.map(&:name).should include "foobarbaz"
    end

    it "does nothing when the resource is not virtual" do
      evaluate_in_context { notify "foobarbaz" }
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foobarbaz").realize
      end

      @scope.compiler.collections.map(&:resources).flatten.map(&:name).should_not include "foobarbaz"
    end
  end

  describe "#collect" do

    it "collects the resource if it was exported" do
      evaluate_in_context { export notify "foobarbaz" }
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foobarbaz").collect
      end

      @scope.compiler.collections.map(&:resources).flatten.map(&:name).should include "foobarbaz"
    end

    it "does nothein when resource is not exported" do
      evaluate_in_context { notify "foobarbaz" }
      evaluate_in_scope do
        Puppet::DSL::ResourceReference.new(@typeref, "foobarbaz").collect
      end

      @scope.compiler.collections.map(&:resources).flatten.map(&:name).should_not include "foobarbaz"
    end

  end

end

