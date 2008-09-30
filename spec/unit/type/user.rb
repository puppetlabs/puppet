#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

user = Puppet::Type.type(:user)

describe user do
    after { user.clear }

    it "should have a default provider inheriting from Puppet::Provider" do
        user.defaultprovider.ancestors.should be_include(Puppet::Provider)
    end

    it "should be able to create a instance" do
        user.create(:name => "foo").should_not be_nil
    end

    describe "instances" do

        it "should have a valid provider" do
            user.create(:name => "foo").provider.class.ancestors.should be_include(Puppet::Provider)
        end
    end
end
