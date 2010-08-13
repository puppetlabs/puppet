#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/dsl/resource_type_api'

class DSLAPITester
  include Puppet::DSL::ResourceTypeAPI
end

describe Puppet::DSL::ResourceTypeAPI do
  before do
    @api = DSLAPITester.new
  end

  [:definition, :node, :hostclass].each do |type|
    method = type == :definition ? "define" : type
    it "should be able to create a #{type}" do
      newtype = @api.send(method, "myname")
      newtype.should be_a(Puppet::Resource::Type)
      newtype.type.should == type
    end

    it "should use the provided name when creating a #{type}" do
      newtype = @api.send(method, "myname")
      newtype.name.should == "myname"
    end

    unless type == :definition
      it "should pass in any provided options when creating a #{type}" do
        newtype = @api.send(method, "myname", :line => 200)
        newtype.line.should == 200
      end
    end

    it "should set any provided block as the type's ruby code"

    it "should add the type to the current environment's known resource types"
  end

  describe "when creating a definition" do
    it "should use the provided options to define valid arguments for the resource type"
  end
end
