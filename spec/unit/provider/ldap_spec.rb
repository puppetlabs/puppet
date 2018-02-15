#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/provider/ldap'

describe Puppet::Provider::Ldap do
  before do
    @class = Class.new(Puppet::Provider::Ldap)
  end

  it "should be able to define its manager" do
    manager = mock 'manager'
    Puppet::Util::Ldap::Manager.expects(:new).returns manager
    @class.stubs :mk_resource_methods
    manager.expects(:manages).with(:one)
    expect(@class.manages(:one)).to equal(manager)
    expect(@class.manager).to equal(manager)
  end

  it "should be able to prefetch instances from ldap" do
    expect(@class).to respond_to(:prefetch)
  end

  it "should create its resource getter/setter methods when the manager is defined" do
    manager = mock 'manager'
    Puppet::Util::Ldap::Manager.expects(:new).returns manager
    @class.expects :mk_resource_methods
    manager.stubs(:manages)
    expect(@class.manages(:one)).to equal(manager)
  end

  it "should have an instances method" do
    expect(@class).to respond_to(:instances)
  end

  describe "when providing a list of instances" do
    it "should convert all results returned from the manager's :search method into provider instances" do
      manager = mock 'manager'
      @class.stubs(:manager).returns manager

      manager.expects(:search).returns %w{one two three}

      @class.expects(:new).with("one").returns(1)
      @class.expects(:new).with("two").returns(2)
      @class.expects(:new).with("three").returns(3)

      expect(@class.instances).to eq([1,2,3])
    end
  end

  it "should have a prefetch method" do
    expect(@class).to respond_to(:prefetch)
  end

  describe "when prefetching" do
    before do
      @manager = mock 'manager'
      @class.stubs(:manager).returns @manager

      @resource = mock 'resource'

      @resources = {"one" => @resource}
    end

    it "should find an entry for each passed resource" do
      @manager.expects(:find).with("one").returns nil

      @class.stubs(:new)
      @resource.stubs(:provider=)
      @class.prefetch(@resources)
    end

    describe "resources that do not exist" do
      it "should create a provider with :ensure => :absent" do
        @manager.expects(:find).with("one").returns nil

        @class.expects(:new).with(:ensure => :absent).returns "myprovider"

        @resource.expects(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end
    end

    describe "resources that exist" do
      it "should create a provider with the results of the find" do
        @manager.expects(:find).with("one").returns("one" => "two")

        @class.expects(:new).with("one" => "two", :ensure => :present).returns "myprovider"

        @resource.expects(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end

      it "should set :ensure to :present in the returned values" do
        @manager.expects(:find).with("one").returns("one" => "two")

        @class.expects(:new).with("one" => "two", :ensure => :present).returns "myprovider"

        @resource.expects(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end
    end
  end

  describe "when being initialized" do
    it "should fail if no manager has been defined" do
      expect { @class.new }.to raise_error(Puppet::DevError)
    end

    it "should fail if the manager is invalid" do
      manager = stub "manager", :valid? => false
      @class.stubs(:manager).returns manager
      expect { @class.new }.to raise_error(Puppet::DevError)
    end

    describe "with a hash" do
      before do
        @manager = stub "manager", :valid? => true
        @class.stubs(:manager).returns @manager

        @resource_class = mock 'resource_class'
        @class.stubs(:resource_type).returns @resource_class

        @property_class = stub 'property_class', :array_matching => :all, :superclass => Puppet::Property
        @resource_class.stubs(:attrclass).with(:one).returns(@property_class)
        @resource_class.stubs(:valid_parameter?).returns true
      end

      it "should store a copy of the hash as its ldap_properties" do
        instance = @class.new(:one => :two)
        expect(instance.ldap_properties).to eq({:one => :two})
      end

      it "should only store the first value of each value array for those attributes that do not match all values" do
        @property_class.expects(:array_matching).returns :first
        instance = @class.new(:one => %w{two three})
        expect(instance.properties).to eq({:one => "two"})
      end

      it "should store the whole value array for those attributes that match all values" do
        @property_class.expects(:array_matching).returns :all
        instance = @class.new(:one => %w{two three})
        expect(instance.properties).to eq({:one => %w{two three}})
      end

      it "should only use the first value for attributes that are not properties" do
        # Yay.  hackish, but easier than mocking everything.
        @resource_class.expects(:attrclass).with(:a).returns Puppet::Type.type(:user).attrclass(:name)
        @property_class.stubs(:array_matching).returns :all

        instance = @class.new(:one => %w{two three}, :a => %w{b c})
        expect(instance.properties).to eq({:one => %w{two three}, :a => "b"})
      end

      it "should discard any properties not valid in the resource class" do
        @resource_class.expects(:valid_parameter?).with(:a).returns false
        @property_class.stubs(:array_matching).returns :all

        instance = @class.new(:one => %w{two three}, :a => %w{b})
        expect(instance.properties).to eq({:one => %w{two three}})
      end
    end
  end

  describe "when an instance" do
    before do
      @manager = stub "manager", :valid? => true
      @class.stubs(:manager).returns @manager
      @instance = @class.new

      @property_class = stub 'property_class', :array_matching => :all, :superclass => Puppet::Property
      @resource_class = stub 'resource_class', :attrclass => @property_class, :valid_parameter? => true, :validproperties => [:one, :two]
      @class.stubs(:resource_type).returns @resource_class
    end

    it "should have a method for creating the ldap entry" do
      expect(@instance).to respond_to(:create)
    end

    it "should have a method for removing the ldap entry" do
      expect(@instance).to respond_to(:delete)
    end

    it "should have a method for returning the class's manager" do
      expect(@instance.manager).to equal(@manager)
    end

    it "should indicate when the ldap entry already exists" do
      @instance = @class.new(:ensure => :present)
      expect(@instance.exists?).to be_truthy
    end

    it "should indicate when the ldap entry does not exist" do
      @instance = @class.new(:ensure => :absent)
      expect(@instance.exists?).to be_falsey
    end

    describe "is being flushed" do
      it "should call the manager's :update method with its name, current attributes, and desired attributes" do
        @instance.stubs(:name).returns "myname"
        @instance.stubs(:ldap_properties).returns(:one => :two)
        @instance.stubs(:properties).returns(:three => :four)
        @manager.expects(:update).with(@instance.name, {:one => :two}, {:three => :four})
        @instance.flush
      end
    end

    describe "is being created" do
      before do
        @rclass = mock 'resource_class'
        @rclass.stubs(:validproperties).returns([:one, :two])
        @resource = mock 'resource'
        @resource.stubs(:class).returns @rclass
        @resource.stubs(:should).returns nil
        @instance.stubs(:resource).returns @resource
      end

      it "should set its :ensure value to :present" do
        @instance.create
        expect(@instance.properties[:ensure]).to eq(:present)
      end

      it "should set all of the other attributes from the resource" do
        @resource.expects(:should).with(:one).returns "oneval"
        @resource.expects(:should).with(:two).returns "twoval"

        @instance.create
        expect(@instance.properties[:one]).to eq("oneval")
        expect(@instance.properties[:two]).to eq("twoval")
      end
    end

    describe "is being deleted" do
      it "should set its :ensure value to :absent" do
        @instance.delete
        expect(@instance.properties[:ensure]).to eq(:absent)
      end
    end
  end
end
