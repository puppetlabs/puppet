#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:group).provider(:groupadd)

describe provider_class do
  before do
    @resource = stub("resource", :name => "mygroup")
    @provider = provider_class.new(@resource)
  end

  it "should add -o when allowdupe is enabled and the group is being created" do
    @resource.stubs(:should).returns "fakeval"
    @resource.stubs(:[]).returns "fakeval"
    @resource.stubs(:system?).returns true
    @resource.expects(:allowdupe?).returns true
    @provider.expects(:execute).with { |args| args.include?("-o") }

    @provider.create
  end

  it "should add -o when allowdupe is enabled and the gid is being modified" do
    @resource.stubs(:should).returns "fakeval"
    @resource.stubs(:[]).returns "fakeval"
    @resource.expects(:allowdupe?).returns true
    @provider.expects(:execute).with { |args| args.include?("-o") }

    @provider.gid = 150
  end

  it "should add -r when system is enabled and the group is being created" do
    @resource.stubs(:should).returns "fakeval"
    @resource.stubs(:[]).returns "fakeval"
    @resource.expects(:system?).returns true
    @resource.stubs(:allowdupe?).returns true
    @provider.expects(:execute).with { |args| args.include?("-r") }

    @provider.create
  end
end
