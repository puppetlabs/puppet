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
    @catalog = Puppet::Resource::Catalog.new
  end

  it "should have a name parameter" do
    @class.attrtype(:name).should == :param
  end

  it "should have :name be its namevar" do
    @class.key_attributes.should == [:name]
  end

  it "should have a :provider parameter" do
    @class.attrtype(:provider).should == :param
  end

  it "should have an ensure property" do
    @class.attrtype(:ensure).should == :property
  end

  it "should support :present as a value for :ensure" do
    proc { @class.new(:name => "whev", :ensure => :present, :user => "nobody") }.should_not raise_error
  end

  it "should support :absent as a value for :ensure" do
    proc { @class.new(:name => "whev", :ensure => :absent, :user => "nobody") }.should_not raise_error
  end

  it "should have an type property" do
    @class.attrtype(:type).should == :property
  end
  it "should support ssh-dss as an type value" do
    proc { @class.new(:name => "whev", :type => "ssh-dss", :user => "nobody") }.should_not raise_error
  end
  it "should support ssh-rsa as an type value" do
    proc { @class.new(:name => "whev", :type => "ssh-rsa", :user => "nobody") }.should_not raise_error
  end
  it "should support :dsa as an type value" do
    proc { @class.new(:name => "whev", :type => :dsa, :user => "nobody") }.should_not raise_error
  end
  it "should support :rsa as an type value" do
    proc { @class.new(:name => "whev", :type => :rsa, :user => "nobody") }.should_not raise_error
  end

  it "should not support values other than ssh-dss, ssh-rsa, dsa, rsa in the ssh_authorized_key_type" do
    proc { @class.new(:name => "whev", :type => :something) }.should raise_error(Puppet::Error)
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

  it "'s options property should return well formed string of arrays from is_to_s" do
    resource = @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => ["a","b","c"])

    resource.property(:options).is_to_s(["a","b","c"]).should == "a,b,c"
  end

  it "'s options property should return well formed string of arrays from is_to_s" do
    resource = @class.new(:name => "whev", :type => :rsa, :user => "nobody", :options => ["a","b","c"])

    resource.property(:options).should_to_s(["a","b","c"]).should == "a,b,c"
  end

  it "should have a target property" do
    @class.attrtype(:target).should == :property
  end

  describe "when neither user nor target is specified" do
    it "should raise an error" do
      proc do

        @class.create(

          :name   => "Test",
          :key    => "AAA",
          :type   => "ssh-rsa",

          :ensure => :present)
      end.should raise_error(Puppet::Error)
    end
  end

  describe "when both target and user are specified" do
    it "should use target" do

      resource = @class.create(

        :name => "Test",
        :user => "root",

        :target => "/tmp/blah")
      resource.should(:target).should == "/tmp/blah"
    end
  end


  describe "when user is specified" do
    it "should determine target" do

      resource = @class.create(

        :name   => "Test",

        :user   => "root")
      target = File.expand_path("~root/.ssh/authorized_keys")
      resource.should(:target).should == target
    end

    # Bug #2124 - ssh_authorized_key always changes target if target is not defined
    it "should not raise spurious change events" do
      resource = @class.new(:name => "Test", :user => "root")
      target = File.expand_path("~root/.ssh/authorized_keys")
      resource.property(:target).safe_insync?(target).should == true
    end
  end

  describe "when calling validate" do
    it "should not crash on a non-existant user" do

      resource = @class.create(

        :name   => "Test",

        :user   => "ihopesuchuserdoesnotexist")
      proc { resource.validate }.should_not raise_error
    end
  end
end
