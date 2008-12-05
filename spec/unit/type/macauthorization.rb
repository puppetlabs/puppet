#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

macauth_type = Puppet::Type.type(:macauthorization)


describe macauth_type, "when validating attributes" do

    parameters = [:name,]
    properties = [:auth_type, :allow_root, :authenticate_user, :auth_class, 
                  :comment, :group, :k_of_n, :mechanisms, :rule, 
                  :session_owner, :shared, :timeout, :tries]
    
    parameters.each do |parameter|
        it "should have a %s parameter" % parameter do
            macauth_type.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
        end

        it "should have documentation for its %s parameter" % parameter do
            macauth_type.attrclass(parameter).doc.should be_instance_of(String)
        end
    end

    properties.each do |property|
        it "should have a %s property" % property do
            macauth_type.attrclass(property).ancestors.should be_include(Puppet::Property)
        end

        it "should have documentation for its %s property" % property do
            macauth_type.attrclass(property).doc.should be_instance_of(String)
        end
    end

end

describe macauth_type, "when validating properties" do
    
    before do
        @provider = stub 'provider'
        @resource = stub 'resource', :resource => nil, :provider => @provider, :line => nil, :file => nil
    end
    
    after do
        macauth_type.clear
    end
    
    it "should have a default provider inheriting from Puppet::Provider" do
        macauth_type.defaultprovider.ancestors.should be_include(Puppet::Provider)
    end

    it "should be able to create a instance" do
        macauth_type.create(:name => "foo").should_not be_nil
    end
    
    it "should be able to create an instance" do
        lambda {
            macauth_type.create(:name => 'foo')
        }.should_not raise_error
    end

    it "should support :present as a value to :ensure" do
        lambda {
            macauth_type.create(:name => "foo", :ensure => :present)
        }.should_not raise_error
    end

    it "should support :absent as a value to :ensure" do
        lambda {
            macauth_type.create(:name => "foo", :ensure => :absent)
        }.should_not raise_error
    end

end

describe "instances" do
    it "should have a valid provider" do
        macauth_type.create(:name => "foo").provider.class.ancestors.should be_include(Puppet::Provider)
    end
end