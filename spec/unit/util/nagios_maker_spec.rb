require 'spec_helper'

require 'puppet/util/nagios_maker'

describe Puppet::Util::NagiosMaker do
  before do
    @module = Puppet::Util::NagiosMaker

    @nagtype = double('nagios type', :parameters => [], :namevar => :name)
    allow(Nagios::Base).to receive(:type).with(:test).and_return(@nagtype)

    @provider = double('provider', :nagios_type => nil)
    @type = double('type', :newparam => nil, :newproperty => nil, :provide => @provider, :desc => nil, :ensurable => nil)
  end

  it "should be able to create a new nagios type" do
    expect(@module).to respond_to(:create_nagios_type)
  end

  it "should fail if it cannot find the named Naginator type" do
    allow(Nagios::Base).to receive(:type).and_return(nil)

    expect { @module.create_nagios_type(:no_such_type) }.to raise_error(Puppet::DevError)
  end

  it "should create a new RAL type with the provided name prefixed with 'nagios_'" do
    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should mark the created type as ensurable" do
    expect(@type).to receive(:ensurable)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a namevar parameter for the nagios type's name parameter" do
    expect(@type).to receive(:newparam).with(:name, :namevar => true)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a property for all non-namevar parameters" do
    allow(@nagtype).to receive(:parameters).and_return([:one, :two])

    expect(@type).to receive(:newproperty).with(:one)
    expect(@type).to receive(:newproperty).with(:two)
    expect(@type).to receive(:newproperty).with(:target)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should skip parameters that start with integers" do
    allow(@nagtype).to receive(:parameters).and_return(["2dcoords".to_sym, :other])

    expect(@type).to receive(:newproperty).with(:other)
    expect(@type).to receive(:newproperty).with(:target)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should deduplicate the parameter list" do
    allow(@nagtype).to receive(:parameters).and_return([:one, :one])

    expect(@type).to receive(:newproperty).with(:one)
    expect(@type).to receive(:newproperty).with(:target)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end

  it "should create a target property" do
    expect(@type).to receive(:newproperty).with(:target)

    expect(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
    @module.create_nagios_type(:test)
  end
end

describe Puppet::Util::NagiosMaker, " when creating the naginator provider" do
  before do
    @module = Puppet::Util::NagiosMaker
    @provider = double('provider', :nagios_type => nil)

    @nagtype = double('nagios type', :parameters => [], :namevar => :name)
    allow(Nagios::Base).to receive(:type).with(:test).and_return(@nagtype)

    @type = double('type', :newparam => nil, :ensurable => nil, :newproperty => nil, :desc => nil)
    allow(Puppet::Type).to receive(:newtype).with(:nagios_test).and_return(@type)
  end

  it "should add a naginator provider" do
    expect(@type).to receive(:provide).with(:naginator, anything).and_return(@provider)

    @module.create_nagios_type(:test)
  end

  it "should set Puppet::Provider::Naginator as the parent class of the provider" do
    expect(@type).to receive(:provide).with(anything, hash_including(parent: Puppet::Provider::Naginator)).and_return(@provider)

    @module.create_nagios_type(:test)
  end

  it "should use /etc/nagios/$name.cfg as the default target" do
    expect(@type).to receive(:provide).with(anything, hash_including(default_target: "/etc/nagios/nagios_test.cfg")).and_return(@provider)

    @module.create_nagios_type(:test)
  end

  it "should trigger the lookup of the Nagios class" do
    expect(@type).to receive(:provide).and_return(@provider)

    expect(@provider).to receive(:nagios_type)

    @module.create_nagios_type(:test)
  end
end
