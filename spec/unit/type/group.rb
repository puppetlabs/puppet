#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:group) do
    before do
        @class = Puppet::Type.type(:group)
    end

    after do
        @class.clear
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
    end

    # #1407 - we need to declare the allowdupe param as boolean.
    it "should have a boolean method for determining if duplicates are allowed" do
        @class.create(:name => "foo").methods.should be_include("allowdupe?")
    end
end
