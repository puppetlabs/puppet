#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/dsl/resource_type_api'

describe Puppet::DSL::ResourceTypeAPI do
  # Run the given block in the context of a new ResourceTypeAPI
  # object.
  def test_api_call(&block)
    Thread.current[:known_resource_types] = Puppet::Resource::TypeCollection.new(:env)
    Puppet::DSL::ResourceTypeAPI.new.instance_eval(&block)
  ensure
    Thread.current[:known_resource_types] = nil
  end

  [:definition, :node, :hostclass].each do |type|
    method = type == :definition ? "define" : type
    it "should be able to create a #{type}" do
      newtype = Puppet::Resource::Type.new(:hostclass, "foo")
      Puppet::Resource::Type.expects(:new).with { |t, n, args| t == type }.returns newtype
      test_api_call { send(method, "myname") }
    end

    it "should use the provided name when creating a #{type}" do
      type = Puppet::Resource::Type.new(:hostclass, "foo")
      Puppet::Resource::Type.expects(:new).with { |t, n, args| n == "myname" }.returns type
      test_api_call { send(method, "myname") }
    end

    unless type == :definition
      it "should pass in any provided options" do
        type = Puppet::Resource::Type.new(:hostclass, "foo")
        Puppet::Resource::Type.expects(:new).with { |t, n, args| args == {:myarg => :myvalue} }.returns type
        test_api_call { send(method, "myname", :myarg => :myvalue) }
      end
    end

    it "should set any provided block as the type's ruby code" do
      Puppet::Resource::Type.any_instance.expects(:ruby_code=).with { |blk| blk.call == 'foo' }
      test_api_call { send(method, "myname") { 'foo' } }
    end

    it "should add the type to the current environment's known resource types" do
      begin
        newtype = Puppet::Resource::Type.new(:hostclass, "foo")
        Puppet::Resource::Type.expects(:new).returns newtype
        known_resource_types = Puppet::Resource::TypeCollection.new(:env)
        Thread.current[:known_resource_types] = known_resource_types
        known_resource_types.expects(:add).with(newtype)
        Puppet::DSL::ResourceTypeAPI.new.instance_eval { hostclass "myname" }
      ensure
        Thread.current[:known_resource_types] = nil
      end
    end
  end

  describe "when creating a definition" do
    it "should use the provided options to define valid arguments for the resource type" do
      newtype = Puppet::Resource::Type.new(:definition, "foo")
      Puppet::Resource::Type.expects(:new).returns newtype
      test_api_call { define("myname", :arg1, :arg2) }
      newtype.instance_eval { @arguments }.should == { 'arg1' => nil, 'arg2' => nil }
    end
  end
end
