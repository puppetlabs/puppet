#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rights'

describe Puppet::Network::Rights do
    before do
        @right = Puppet::Network::Rights.new
    end

    [:allow, :allowed?, :deny].each do |m|
        it "should have a #{m} method" do
            @right.should respond_to(m)
        end

        describe "when using #{m}" do
            it "should delegate to the correct acl" do
                acl = stub 'acl'
                @right.stubs(:right).returns(acl)

                acl.expects(m).with("me")

                @right.send(m, 'thisacl', "me")
            end
        end
    end

    describe "when creating new ACLs" do
        it "should throw an error if the ACL already exists" do
            @right.newright("name")

            lambda { @right.newright("name")}.should raise_error
        end

        it "should create a new ACL with the correct name" do
            @right.newright("name")

            @right["name"].name.should == :name
        end

        it "should create an ACL of type Puppet::Network::AuthStore" do
            @right.newright("name")

            @right["name"].should be_a_kind_of(Puppet::Network::AuthStore)
        end

        it "should create an ACL with a shortname" do
            @right.newright("name")

            @right["name"].shortname.should == "n"
        end
    end
end
