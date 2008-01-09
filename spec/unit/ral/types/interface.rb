#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

interface = Puppet::Type.type(:interface)

describe interface do
    before do
        @class = Puppet::Type.type(:interface)

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

    it "should have an interface_type property" do
        @class.attrtype(:interface_type).should == :property
    end
    it "should support :loopback as an interface_type value" do
        proc { @class.create(:name => "whev", :interface_type => :loopback) }.should_not raise_error
    end
    it "should support :alias as an interface_type value" do
        proc { @class.create(:name => "whev", :interface_type => :alias) }.should_not raise_error
    end
    it "should support :normal as an interface_type value" do
        proc { @class.create(:name => "whev", :interface_type => :normal) }.should_not raise_error
    end
    it "should alias :dummy to the :loopback interface_type value" do
        int = @class.create(:name => "whev", :interface_type => :dummy)
        int.should(:interface_type).should == :loopback
    end

    it "should not support values other than :loopback, :alias, :normal, and :dummy in the interface_type" do
        proc { @class.create(:name => "whev", :interface_type => :something) }.should raise_error(Puppet::Error)
    end

    it "should have an interface_desc parameter" do
        @class.attrtype(:interface_desc).should == :param
    end

    it "should have an onboot property" do
        @class.attrtype(:onboot).should == :property
    end
    it "should support :true as an onboot value" do
        proc { @class.create(:name => "whev", :onboot => :true) }.should_not raise_error
    end
    it "should support :false as an onboot value" do
        proc { @class.create(:name => "whev", :onboot => :false) }.should_not raise_error
    end

    it "should have an ifnum property" do
        @class.attrtype(:ifnum).should == :property
    end

    it "should have a netmask property" do
        @class.attrtype(:netmask).should == :property
    end

    it "should have an ifopts property" do
        @class.attrtype(:ifopts).should == :property
    end

    it "should have a target parameter" do
        @class.attrtype(:target).should == :param
    end
end
