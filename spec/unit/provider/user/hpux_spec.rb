#!/usr/bin/env ruby
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

describe provider_class do

  it "should have feature manages_passwords" do
      provider_class.should be_manages_passwords
  end

  it "should return nil if user does not exist" do
      @resource = stub("resource", :name => "no_user")
      @provider = provider_class.new(@resource)
      @provider.password.must be_nil
  end


  it "should return password entry if exists" do
      @resource = stub("resource", :name => "root")
      @provider = provider_class.new(@resource)
      @provider.password.should be_true
  end
end
