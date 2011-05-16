#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:group) do
  before do
    ENV["PATH"] += File::PATH_SEPARATOR + "/usr/sbin" unless ENV["PATH"].split(File::PATH_SEPARATOR).include?("/usr/sbin")
    @class = Puppet::Type.type(:group)
  end

  it "should have a default provider" do
    @class.defaultprovider.should_not be_nil
  end

  it "should have a default provider inheriting from Puppet::Provider" do
    @class.defaultprovider.ancestors.should be_include(Puppet::Provider)
  end

  it "should have a system_groups feature" do
    @class.provider_feature(:system_groups).should_not be_nil
  end

  describe "when validating attributes" do
    [:name, :allowdupe].each do |param|
      it "should have a #{param} parameter" do
        @class.attrtype(param).should == :param
      end
    end

    [:ensure, :gid].each do |param|
      it "should have a #{param} property" do
        @class.attrtype(param).should == :property
      end
    end

    it "should convert gids provided as strings into integers" do
      @class.new(:name => "foo", :gid => "15")[:gid].should == 15
    end

    it "should accepts gids provided as integers" do
      @class.new(:name => "foo", :gid => 15)[:gid].should == 15
    end
  end

  it "should have a boolean method for determining if duplicates are allowed", :'fails_on_ruby_1.9.2' => true do
    @class.new(:name => "foo").methods.should be_include("allowdupe?")
  end

  it "should have a boolean method for determining if system groups are allowed", :'fails_on_ruby_1.9.2' => true do
    @class.new(:name => "foo").methods.should be_include("system?")
  end

  it "should call 'create' to create the group" do
    group = @class.new(:name => "foo", :ensure => :present)
    group.provider.expects(:create)
    group.parameter(:ensure).sync
  end

  it "should call 'delete' to remove the group" do
    group = @class.new(:name => "foo", :ensure => :absent)
    group.provider.expects(:delete)
    group.parameter(:ensure).sync
  end
end
