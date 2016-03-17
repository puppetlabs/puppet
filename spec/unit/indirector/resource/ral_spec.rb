#! /usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Resource::Ral" do

  it "disallows remote requests" do
    expect(Puppet::Resource::Ral.new.allow_remote_requests?).to eq(false)
  end

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
      expect(Puppet::Resource::Ral.new.find(@request)).to eq(my_resource)
    end

    it "should produce Puppet::Error instead of ArgumentError" do
      @bad_request = stub 'thiswillcauseanerror', :key => "thiswill/causeanerror"
      expect{Puppet::Resource::Ral.new.find(@bad_request)}.to raise_error(Puppet::Error)
    end

    it "if there is no instance, it should create one" do
      wrong_instance = stub "wrong user", :name => "bob"
      root = mock "Root User"
      root_resource = mock "Root Resource"

      require 'puppet/type/user'
      Puppet::Type::User.expects(:instances).returns([ wrong_instance, wrong_instance ])
      Puppet::Type::User.expects(:new).with(has_entry(:name => "root")).returns(root)
      root.expects(:to_resource).returns(root_resource)

      result = Puppet::Resource::Ral.new.find(@request)

      expect(result).to eq(root_resource)
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
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
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
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
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
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([my_resource])
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
      expect(Puppet::Resource::Ral.new.search(@request)).to eq([a_resource, b_resource])
    end
  end

  describe "save" do
    it "returns a report covering the application of the given resource to the system" do
      resource = Puppet::Resource.new(:notify, "the title")
      ral = Puppet::Resource::Ral.new

      applied_resource, report = ral.save(Puppet::Indirector::Request.new(:ral, :save, 'testing', resource, :environment => Puppet::Node::Environment.remote(:testing)))

      expect(applied_resource.title).to eq("the title")
      expect(report.environment).to eq("testing")
      expect(report.resource_statuses["Notify[the title]"].changed).to eq(true)
    end
  end
end
