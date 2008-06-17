#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:user).provider(:useradd)

describe provider_class do
    before do
        @resource = stub("resource", :name => "myuser", :managehome? => nil)
        @provider = provider_class.new(@resource)
    end

    # #1360
    it "should add -o when allowdupe is enabled and the user is being created" do
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @resource.expects(:allowdupe?).returns true
        @provider.expects(:execute).with { |args| args.include?("-o") }

        @provider.create
    end

    it "should add -o when allowdupe is enabled and the uid is being modified" do
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @resource.expects(:allowdupe?).returns true
        @provider.expects(:execute).with { |args| args.include?("-o") }

        @provider.uid = 150
    end
end
