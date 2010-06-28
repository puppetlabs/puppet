#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:group) do
    before do
        unless ENV["PATH"].split(File::PATH_SEPARATOR).include?("/usr/sbin")
            ENV["PATH"] += File::PATH_SEPARATOR + "/usr/sbin"
        end
        @class = Puppet::Type.type(:group)
    end

    it "should have a default provider" do
        @class.defaultprovider.should_not be_nil
    end

    it "should have a default provider inheriting from Puppet::Provider" do
        @class.defaultprovider.ancestors.should be_include(Puppet::Provider)
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

    # #1407 - we need to declare the allowdupe param as boolean.
    it "should have a boolean method for determining if duplicates are allowed" do
        @class.new(:name => "foo").methods.should be_include("allowdupe?")
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
