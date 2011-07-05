#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/util/nagios_maker'

describe Puppet::Util::NagiosMaker do
  before do
    @module = Puppet::Util::NagiosMaker

    @nagtype = stub 'nagios type', :parameters => [], :namevar => :name, :name => "nagtype"
    @nagtype.stubs(:attr_accessor)
    Nagios::Base.stubs(:type).returns(@nagtype)

    @provider = stub 'provider', :nagios_type => nil
    @type = Puppet::Type.newtype(:test_nag_type)
  end

  after do
    Puppet::Type.rmtype(:test_nag_type)
  end

  it "should be able to create a new nagios type" do
    @module.should respond_to(:create_nagios_type)
  end

  it "should fail if it cannot find the named Naginator type" do
    Nagios::Base.stubs(:type).returns(nil)

    lambda { @module.create_nagios_type(:no_such_type) }.should raise_error(Puppet::DevError)
  end

  it "should create a new RAL type with the provided name prefixed with 'nagios_'" do
    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should mark the created type as ensurable" do
    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)

    @type.property_names.should be_include(:ensure)
  end

  it "should create a namevar parameter for the nagios type's name parameter" do
    @type.expects(:newparam).with(:name, :namevar => true)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a property for all non-namevar parameters" do
    @nagtype.stubs(:parameters).returns([:one, :two])

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)

    @type.property_names.should be_include(:one)
    @type.property_names.should be_include(:two)
  end

  it "should skip parameters that start with integers" do
    @nagtype.stubs(:parameters).returns([:"2dcoords", :other])

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)

    @type.property_names.should_not be_include(:"2dcoords")
  end

  it "should deduplicate the parameter list" do
    @nagtype.stubs(:parameters).returns([:one, :one])

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    lambda { @module.create_nagios_type(:test) }.should_not raise_error
  end

  it "should create a target property" do
    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)

    @type.property_names.should be_include(:target)
  end
end

describe Puppet::Util::NagiosMaker, " when creating the naginator provider" do
  before do
    @module = Puppet::Util::NagiosMaker
    @provider = stub 'provider', :nagios_type => nil

    @nagtype = stub 'nagios type', :parameters => [], :namevar => :name
    Nagios::Base.stubs(:type).with(:test).returns(@nagtype)

    @type = stub 'type', :newparam => nil, :ensurable => nil, :newproperty => nil, :desc => nil
    Puppet::Type.stubs(:newtype).with(:nagios_test).returns(@type)
  end

  it "should add a naginator provider" do
    @type.expects(:provide).with { |name, options| name == :naginator }.returns @provider

    @module.create_nagios_type(:test)
  end

  it "should set Puppet::Provider::Naginator as the parent class of the provider" do
    @type.expects(:provide).with { |name, options| options[:parent] == Puppet::Provider::Naginator }.returns @provider

    @module.create_nagios_type(:test)
  end

  it "should use /etc/nagios/$name.cfg as the default target" do
    @type.expects(:provide).with { |name, options| options[:default_target] == "/etc/nagios/nagios_test.cfg" }.returns @provider

    @module.create_nagios_type(:test)
  end

  it "should trigger the lookup of the Nagios class" do
    @type.expects(:provide).returns @provider

    @provider.expects(:nagios_type)

    @module.create_nagios_type(:test)
  end
end
