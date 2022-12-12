require 'spec_helper'

require 'puppet/provider/ldap'

describe Puppet::Provider::Ldap do
  before do
    @class = Class.new(Puppet::Provider::Ldap)
  end

  it "should be able to define its manager" do
    manager = double('manager')
    expect(Puppet::Util::Ldap::Manager).to receive(:new).and_return(manager)
    allow(@class).to receive(:mk_resource_methods)
    expect(manager).to receive(:manages).with(:one)
    expect(@class.manages(:one)).to equal(manager)
    expect(@class.manager).to equal(manager)
  end

  it "should be able to prefetch instances from ldap" do
    expect(@class).to respond_to(:prefetch)
  end

  it "should create its resource getter/setter methods when the manager is defined" do
    manager = double('manager')
    expect(Puppet::Util::Ldap::Manager).to receive(:new).and_return(manager)
    expect(@class).to receive(:mk_resource_methods)
    allow(manager).to receive(:manages)
    expect(@class.manages(:one)).to equal(manager)
  end

  it "should have an instances method" do
    expect(@class).to respond_to(:instances)
  end

  describe "when providing a list of instances" do
    it "should convert all results returned from the manager's :search method into provider instances" do
      manager = double('manager')
      allow(@class).to receive(:manager).and_return(manager)

      expect(manager).to receive(:search).and_return(%w{one two three})

      expect(@class).to receive(:new).with("one").and_return(1)
      expect(@class).to receive(:new).with("two").and_return(2)
      expect(@class).to receive(:new).with("three").and_return(3)

      expect(@class.instances).to eq([1,2,3])
    end
  end

  it "should have a prefetch method" do
    expect(@class).to respond_to(:prefetch)
  end

  describe "when prefetching" do
    before do
      @manager = double('manager')
      allow(@class).to receive(:manager).and_return(@manager)

      @resource = double('resource')

      @resources = {"one" => @resource}
    end

    it "should find an entry for each passed resource" do
      expect(@manager).to receive(:find).with("one").and_return(nil)

      allow(@class).to receive(:new)
      allow(@resource).to receive(:provider=)
      @class.prefetch(@resources)
    end

    describe "resources that do not exist" do
      it "should create a provider with :ensure => :absent" do
        expect(@manager).to receive(:find).with("one").and_return(nil)

        expect(@class).to receive(:new).with({:ensure => :absent}).and_return("myprovider")

        expect(@resource).to receive(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end
    end

    describe "resources that exist" do
      it "should create a provider with the results of the find" do
        expect(@manager).to receive(:find).with("one").and_return("one" => "two")

        expect(@class).to receive(:new).with({"one" => "two", :ensure => :present}).and_return("myprovider")

        expect(@resource).to receive(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end

      it "should set :ensure to :present in the returned values" do
        expect(@manager).to receive(:find).with("one").and_return("one" => "two")

        expect(@class).to receive(:new).with({"one" => "two", :ensure => :present}).and_return("myprovider")

        expect(@resource).to receive(:provider=).with("myprovider")

        @class.prefetch(@resources)
      end
    end
  end

  describe "when being initialized" do
    it "should fail if no manager has been defined" do
      expect { @class.new }.to raise_error(Puppet::DevError)
    end

    it "should fail if the manager is invalid" do
      manager = double("manager", :valid? => false)
      allow(@class).to receive(:manager).and_return(manager)
      expect { @class.new }.to raise_error(Puppet::DevError)
    end

    describe "with a hash" do
      before do
        @manager = double("manager", :valid? => true)
        allow(@class).to receive(:manager).and_return(@manager)

        @resource_class = double('resource_class')
        allow(@class).to receive(:resource_type).and_return(@resource_class)

        @property_class = double('property_class', :array_matching => :all, :superclass => Puppet::Property)
        allow(@resource_class).to receive(:attrclass).with(:one).and_return(@property_class)
        allow(@resource_class).to receive(:valid_parameter?).and_return(true)
      end

      it "should store a copy of the hash as its ldap_properties" do
        instance = @class.new(:one => :two)
        expect(instance.ldap_properties).to eq({:one => :two})
      end

      it "should only store the first value of each value array for those attributes that do not match all values" do
        expect(@property_class).to receive(:array_matching).and_return(:first)
        instance = @class.new(:one => %w{two three})
        expect(instance.properties).to eq({:one => "two"})
      end

      it "should store the whole value array for those attributes that match all values" do
        expect(@property_class).to receive(:array_matching).and_return(:all)
        instance = @class.new(:one => %w{two three})
        expect(instance.properties).to eq({:one => %w{two three}})
      end

      it "should only use the first value for attributes that are not properties" do
        # Yay.  hackish, but easier than mocking everything.
        expect(@resource_class).to receive(:attrclass).with(:a).and_return(Puppet::Type.type(:user).attrclass(:name))
        allow(@property_class).to receive(:array_matching).and_return(:all)

        instance = @class.new(:one => %w{two three}, :a => %w{b c})
        expect(instance.properties).to eq({:one => %w{two three}, :a => "b"})
      end

      it "should discard any properties not valid in the resource class" do
        expect(@resource_class).to receive(:valid_parameter?).with(:a).and_return(false)
        allow(@property_class).to receive(:array_matching).and_return(:all)

        instance = @class.new(:one => %w{two three}, :a => %w{b})
        expect(instance.properties).to eq({:one => %w{two three}})
      end
    end
  end

  describe "when an instance" do
    before do
      @manager = double("manager", :valid? => true)
      allow(@class).to receive(:manager).and_return(@manager)
      @instance = @class.new

      @property_class = double('property_class', :array_matching => :all, :superclass => Puppet::Property)
      @resource_class = double('resource_class', :attrclass => @property_class, :valid_parameter? => true, :validproperties => [:one, :two])
      allow(@class).to receive(:resource_type).and_return(@resource_class)
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
        allow(@instance).to receive(:name).and_return("myname")
        allow(@instance).to receive(:ldap_properties).and_return(:one => :two)
        allow(@instance).to receive(:properties).and_return(:three => :four)
        expect(@manager).to receive(:update).with(@instance.name, {:one => :two}, {:three => :four})
        @instance.flush
      end
    end

    describe "is being created" do
      before do
        @rclass = double('resource_class')
        allow(@rclass).to receive(:validproperties).and_return([:one, :two])
        @resource = double('resource')
        allow(@resource).to receive(:class).and_return(@rclass)
        allow(@resource).to receive(:should).and_return(nil)
        allow(@instance).to receive(:resource).and_return(@resource)
      end

      it "should set its :ensure value to :present" do
        @instance.create
        expect(@instance.properties[:ensure]).to eq(:present)
      end

      it "should set all of the other attributes from the resource" do
        expect(@resource).to receive(:should).with(:one).and_return("oneval")
        expect(@resource).to receive(:should).with(:two).and_return("twoval")

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
