#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/nagios_maker'

describe Puppet::Util::NagiosMaker do
  before do
    @module = Puppet::Util::NagiosMaker

    @nagtype = stub 'nagios type', :parameters => [], :namevar => :name
    Nagios::Base.stubs(:type).with(:test).returns(@nagtype)

    @provider = stub 'provider', :nagios_type => nil
    @type = stub 'type', :newparam => nil, :newproperty => nil, :provide => @provider, :desc => nil, :ensurable => nil
  end

  it "should be able to create a new nagios type" do
    expect(@module).to respond_to(:create_nagios_type)
  end

  it "should fail if it cannot find the named Naginator type" do
    Nagios::Base.stubs(:type).returns(nil)

    expect { @module.create_nagios_type(:no_such_type) }.to raise_error(Puppet::DevError)
  end

  it "should create a new RAL type with the provided name prefixed with 'nagios_'" do
    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should mark the created type as ensurable" do
    @type.expects(:ensurable)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a namevar parameter for the nagios type's name parameter" do
    @type.expects(:newparam).with(:name, :namevar => true)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a property for all non-namevar parameters" do
    @nagtype.stubs(:parameters).returns([:one, :two])

    @type.expects(:newproperty).with(:one)
    @type.expects(:newproperty).with(:two)
    @type.expects(:newproperty).with(:target)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should skip parameters that start with integers" do
    @nagtype.stubs(:parameters).returns(["2dcoords".to_sym, :other])

    @type.expects(:newproperty).with(:other)
    @type.expects(:newproperty).with(:target)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should deduplicate the parameter list" do
    @nagtype.stubs(:parameters).returns([:one, :one])

    @type.expects(:newproperty).with(:one)
    @type.expects(:newproperty).with(:target)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a target property" do
    @type.expects(:newproperty).with(:target)

    Puppet::Type.expects(:newtype).with(:nagios_test).returns(@type)
    @module.create_nagios_type(:test)
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
