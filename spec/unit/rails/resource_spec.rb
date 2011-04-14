#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/rails'

describe "Puppet::Rails::Resource", :if => Puppet.features.rails? do
  def column(name, type)
    ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
  end

  before do
    require 'puppet/rails/resource'

    # Stub this so we don't need access to the DB.
    Puppet::Rails::Resource.stubs(:columns).returns([column("title", "string"), column("restype", "string"), column("exported", "boolean")])
  end

  describe "when creating initial resource arguments" do
    it "should set the restype to the resource's type" do
      Puppet::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:restype].should == "File"
    end

    it "should set the title to the resource's title" do
      Puppet::Rails::Resource.rails_resource_initial_args(Puppet::Resource.new(:file, "/file"))[:title].should == "/file"
    end

    it "should set the line to the resource's line if one is available" do
      resource = Puppet::Resource.new(:file, "/file")
      resource.line = 50

      Puppet::Rails::Resource.rails_resource_initial_args(resource)[:line].should == 50
    end

    it "should set 'exported' to true of the resource is exported" do
      resource = Puppet::Resource.new(:file, "/file")
      resource.exported = true

      Puppet::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_true
    end

    it "should set 'exported' to false of the resource is not exported" do
      resource = Puppet::Resource.new(:file, "/file")
      resource.exported = false

      Puppet::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_false

      resource = Puppet::Resource.new(:file, "/file")
      resource.exported = nil

      Puppet::Rails::Resource.rails_resource_initial_args(resource)[:exported].should be_false
    end
  end

  describe "when merging in a parser resource" do
    before do
      @parser = mock 'parser resource'

      @resource = Puppet::Rails::Resource.new
      [:merge_attributes, :merge_parameters, :merge_tags, :save].each { |m| @resource.stubs(m) }
    end

    it "should merge the attributes" do
      @resource.expects(:merge_attributes).with(@parser)

      @resource.merge_parser_resource(@parser)
    end

    it "should merge the parameters" do
      @resource.expects(:merge_parameters).with(@parser)

      @resource.merge_parser_resource(@parser)
    end

    it "should merge the tags" do
      @resource.expects(:merge_tags).with(@parser)

      @resource.merge_parser_resource(@parser)
    end

    it "should save itself" do
      @resource.expects(:save)

      @resource.merge_parser_resource(@parser)
    end
  end

  describe "merge_parameters" do
    it "should replace values that have changed" do
      @resource = Puppet::Rails::Resource.new
      @resource.params_list = [{"name" => "replace", "value" => 1, "id" => 100 }]

      Puppet::Rails::ParamValue.expects(:delete).with([100])
      param_values = stub "param_values"
      param_values.expects(:build).with({:value=>nil, :param_name=>nil, :line=>{"replace"=>2}})
      @resource.stubs(:param_values).returns(param_values)

      Puppet::Rails::ParamName.stubs(:accumulate_by_name)

      merge_resource = stub "merge_resource"
      merge_resource.expects(:line).returns({ "replace" => 2 })
      merge_resource.stubs(:each).yields([["replace", 2]])

      @resource.merge_parameters(merge_resource)
    end
  end

  describe "#to_resource" do
    it "should instantiate a Puppet::Parser::Resource" do
      scope = stub "scope", :source => nil, :environment => nil, :namespaces => nil

      @resource = Puppet::Rails::Resource.new
      @resource.stubs(:attributes).returns({
        "restype" => 'notify',
        "title"   => 'hello'
      })
      @resource.stubs(:param_names).returns([])

      @resource.to_resource(scope).should be_a(Puppet::Parser::Resource)

    end
  end
end
