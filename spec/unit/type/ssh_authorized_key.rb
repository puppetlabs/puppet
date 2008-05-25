#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

ssh_authorized_key = Puppet::Type.type(:ssh_authorized_key)

describe ssh_authorized_key do
    before do
        @class = Puppet::Type.type(:ssh_authorized_key)

        @provider_class = stub 'provider_class', :name => "fake", :suitable? => true, :supports_parameter? => true
        @class.stubs(:defaultprovider).returns(@provider_class)
        @class.stubs(:provider).returns(@provider_class)

        @provider = stub 'provider', :class => @provider_class, :file_path => "/tmp/whatever", :clear => nil
        @provider_class.stubs(:new).returns(@provider)
    end

    it "should have a name parameter" do
        @class.attrtype(:name).should == :param
    end

    it "should have :name be its namevar" do
        @class.namevar.should == :name
    end

    it "should have a :provider parameter" do
        @class.attrtype(:provider).should == :param
    end

    it "should have an ensure property" do
        @class.attrtype(:ensure).should == :property
    end

    it "should support :present as a value for :ensure" do
        proc { @class.create(:name => "whev", :ensure => :present) }.should_not raise_error
    end

    it "should support :absent as a value for :ensure" do
        proc { @class.create(:name => "whev", :ensure => :absent) }.should_not raise_error
    end

    it "should have an type property" do
        @class.attrtype(:type).should == :property
    end
    it "should support ssh-dss as an type value" do
        proc { @class.create(:name => "whev", :type => "ssh-dss") }.should_not raise_error
    end
    it "should support ssh-rsa as an type value" do
        proc { @class.create(:name => "whev", :type => "ssh-rsa") }.should_not raise_error
    end
    it "should support :dsa as an type value" do
        proc { @class.create(:name => "whev", :type => :dsa) }.should_not raise_error
    end
    it "should support :rsa as an type value" do
        proc { @class.create(:name => "whev", :type => :rsa) }.should_not raise_error
    end

    it "should not support values other than ssh-dss, ssh-rsa, dsa, rsa in the ssh_authorized_key_type" do
        proc { @class.create(:name => "whev", :type => :something) }.should raise_error(Puppet::Error)
    end

    it "should have an key property" do
        @class.attrtype(:key).should == :property
    end

    it "should have an user property" do
        @class.attrtype(:user).should == :property
    end

    it "should have an options property" do
        @class.attrtype(:options).should == :property
    end

    it "should have a target property" do
        @class.attrtype(:target).should == :property
    end
end
