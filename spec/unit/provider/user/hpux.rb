#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:user).provider(:hpuxuseradd)

describe provider_class do
    # left from the useradd test... I have no clue what I'm doing.
    before do
        @resource = stub("resource", :name => "myuser", :managehome? => nil)
        @provider = provider_class.new(@resource)
    end

    it "should add -F when modifying a user" do
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @provider.expects(:execute).with { |args| args.include?("-F") }

        @provider.modify
    end

    it "should add -F when deleting a user" do
        @resource.stubs(:should).returns "fakeval"
        @resource.stubs(:[]).returns "fakeval"
        @provider.expects(:execute).with { |args| args.include?("-F") }

        @provider.delete
    end
end
