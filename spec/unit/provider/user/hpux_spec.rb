#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:hpuxuseradd)

describe provider_class do
  # left from the useradd test... I have no clue what I'm doing.
  before do
    @resource = stub("resource", :name => "myuser", :managehome? => nil, :should => "fakeval", :[] => "fakeval")
    @provider = provider_class.new(@resource)
  end

  it "should add -F when modifying a user" do
    @resource.expects(:allowdupe?).returns true
    @provider.expects(:execute).with { |args| args.include?("-F") }
    @provider.uid = 1000
  end

  it "should add -F when deleting a user" do
    @provider.stubs(:exists?).returns(true)
    @provider.expects(:execute).with { |args| args.include?("-F") }
    @provider.delete
  end
end
