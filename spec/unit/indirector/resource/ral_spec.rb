#!/usr/bin/env rspec
require 'spec_helper'

describe "Puppet::Resource::Ral" do
  describe "find" do
    before do
      @request = stub 'request', :key => "user/root"
    end

    it "should find an existing instance" do
      my_resource    = stub "my user resource"

      wrong_instance = stub "wrong user", :name => "bob"
      my_instance    = stub "my user",    :name => "root", :to_resource => my_resource

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ wrong_instance, my_instance, wrong_instance ])
      Puppet::Resource::Ral.new.find(@request).should == my_resource
    end

    it "if there is no instance, it should create one" do
      wrong_instance = stub "wrong user", :name => "bob"

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ wrong_instance, wrong_instance ])
      result = Puppet::Resource::Ral.new.find(@request)
      result.should be_is_a(Puppet::Resource)
      result.title.should == "root"
    end
  end

  describe "search" do
    before do
      @request = stub 'request', :key => "user/", :options => {}
    end

    it "should convert ral resources into regular resources" do
      my_resource = stub "my user resource"
      my_instance = stub "my user", :name => "root", :to_resource => my_resource

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ my_instance ])
      Puppet::Resource::Ral.new.search(@request).should == [my_resource]
    end

    it "should filter results by name if there's a name in the key" do
      my_resource    = stub "my user resource"
      my_resource.stubs(:to_resource).returns(my_resource)
      my_resource.stubs(:[]).with(:name).returns("root")

      wrong_resource = stub "wrong resource"
      wrong_resource.stubs(:to_resource).returns(wrong_resource)
      wrong_resource.stubs(:[]).with(:name).returns("bad")

      my_instance    = stub "my user",    :to_resource => my_resource
      wrong_instance = stub "wrong user", :to_resource => wrong_resource

      @request = stub 'request', :key => "user/root", :options => {}

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ my_instance, wrong_instance ])
      Puppet::Resource::Ral.new.search(@request).should == [my_resource]
    end

    it "should filter results by query parameters" do
      wrong_resource = stub "my user resource"
      wrong_resource.stubs(:to_resource).returns(wrong_resource)
      wrong_resource.stubs(:[]).with(:name).returns("root")

      my_resource = stub "wrong resource"
      my_resource.stubs(:to_resource).returns(my_resource)
      my_resource.stubs(:[]).with(:name).returns("bob")

      my_instance    = stub "my user",    :to_resource => my_resource
      wrong_instance = stub "wrong user", :to_resource => wrong_resource

      @request = stub 'request', :key => "user/", :options => {:name => "bob"}

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ my_instance, wrong_instance ])
      Puppet::Resource::Ral.new.search(@request).should == [my_resource]
    end

    it "should return sorted results" do
      a_resource = stub "alice resource"
      a_resource.stubs(:to_resource).returns(a_resource)
      a_resource.stubs(:title).returns("alice")

      b_resource = stub "bob resource"
      b_resource.stubs(:to_resource).returns(b_resource)
      b_resource.stubs(:title).returns("bob")

      a_instance = stub "alice user", :to_resource => a_resource
      b_instance = stub "bob user",   :to_resource => b_resource

      @request = stub 'request', :key => "user/", :options => {}

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ b_instance, a_instance ])
      Puppet::Resource::Ral.new.search(@request).should == [a_resource, b_resource]
    end
  end

  describe "save" do
    before do
      @rebuilt_res = stub 'rebuilt instance'
      @ral_res     = stub 'ral resource', :to_resource => @rebuilt_res
      @instance    = stub 'instance', :to_ral => @ral_res
      @request     = stub 'request',  :key => "user/", :instance => @instance
      @catalog     = stub 'catalog'
      @report      = stub 'report'
      @transaction = stub 'transaction', :report => @report

      Puppet::Resource::Catalog.stubs(:new).returns(@catalog)
      @catalog.stubs(:apply).returns(@transaction)
      @catalog.stubs(:add_resource)
    end

    it "should apply a new catalog with a ral object in it" do
      Puppet::Resource::Catalog.expects(:new).returns(@catalog)
      @catalog.expects(:add_resource).with(@ral_res)
      @catalog.expects(:apply).returns(@transaction)
      Puppet::Resource::Ral.new.save(@request).should
    end

    it "should return a regular resource that used to be the ral resource" do
      Puppet::Resource::Ral.new.save(@request).should == [@rebuilt_res, @report]
    end
  end
end
