#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/dsl/resource_type_api'

describe Puppet::DSL::ResourceTypeAPI do
  # Verify that the block creates a single AST node through the API,
  # instantiate that AST node into a types, and return that type.
  def test_api_call(&block)
    main_object = Puppet::DSL::ResourceTypeAPI.new
    main_object.instance_eval(&block)
    created_ast_objects = main_object.instance_eval { @__created_ast_objects__ }
    created_ast_objects.length.should == 1
    new_types = created_ast_objects[0].instantiate('')
    new_types.length.should == 1
    new_types[0]
  ensure
    Thread.current[:ruby_file_parse_result] = nil
  end

  [:definition, :node, :hostclass].each do |type|
    method = type == :definition ? "define" : type
    it "should be able to create a #{type}" do
      newtype = test_api_call { send(method, "myname").should == nil }
      newtype.should be_a(Puppet::Resource::Type)
      newtype.type.should == type
    end

    it "should use the provided name when creating a #{type}" do
      newtype = test_api_call { send(method, "myname") }
      newtype.name.should == "myname"
    end

    unless type == :definition
      it "should pass in any provided options when creating a #{type}" do
        newtype = test_api_call { send(method, "myname", :line => 200) }
        newtype.line.should == 200
      end
    end

    it "should set any provided block as the type's ruby code" do
      newtype = test_api_call { send(method, "myname") { 'method_result' } }
      newtype.ruby_code.call.should == 'method_result'
    end
  end

  describe "when creating a definition" do
    it "should use the provided options to define valid arguments for the resource type" do
      newtype = test_api_call { define("myname", :arg1, :arg2) }
      newtype.arguments.should == { 'arg1' => nil, 'arg2' => nil }
    end
  end
end
