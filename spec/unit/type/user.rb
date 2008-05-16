#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

module UserTestFunctions
    def mkuser(name)
        user = nil;
        lambda {
            user = Puppet::Type.type(:user).create(
                :name => name,
                :comment => "Puppet Testing User",
                :gid => Puppet::Util::SUIDManager.gid,
                :shell => "/bin/sh",
                :home => "/home/%s" % name
        ) }.should_not raise_error
        user.should_not be_nil
        user
    end

    def test_provider_class(klass)
        klass.should_not be_nil
        klass.should be_an_instance_of(Class)
        superclasses = []
        while klass = klass.superclass
            superclasses << klass
        end
        superclasses.should include(Puppet::Provider)
    end
end

describe Puppet::Type.type(:user) do

    include UserTestFunctions

    it "should have a default provider inheriting from Puppet::Provider" do
        test_provider_class Puppet::Type.type(:user).defaultprovider
    end

    it "should be able to create a instance" do
        mkuser "123testuser1"
    end
end

describe Puppet::Type.type(:user), "instances" do

    include UserTestFunctions

    it "should have a valid provider" do
        user = mkuser "123testuser2"
        user.provider.should_not be_nil
        test_provider_class user.provider.class
    end

end


