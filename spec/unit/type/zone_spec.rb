#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:zone) do
  let(:zone)     { described_class.new(:name => 'dummy', :path => '/dummy', :provider => :solaris, :ip=>'if:1.2.3.4:2.3.4.5', :inherit=>'/', :dataset=>'tank') }
  let(:provider) { zone.provider }
  let(:ip)      { zone.property(:ip) }
  let(:inherit) { zone.property(:inherit) }
  let(:dataset) { zone.property(:dataset) }

  parameters = [:create_args, :install_args, :sysidcfg, :realhostname]

  parameters.each do |parameter|
    it "should have a #{parameter} parameter" do
      described_class.attrclass(parameter).ancestors.should be_include(Puppet::Parameter)
    end
  end

  properties = [:ip, :iptype, :autoboot, :pool, :shares, :inherit, :path]

  properties.each do |property|
    it "should have a #{property} property" do
      described_class.attrclass(property).ancestors.should be_include(Puppet::Property)
    end
  end

  describe  "when trying to set a property that is empty" do
    it "should verify that property.insync? of nil or :absent is true" do
      [inherit, ip, dataset].each do |prop|
        prop.stubs(:should).returns []
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(nil).should be_true
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(:absent).should be_true
      end
    end
  end
  describe  "when trying to set a property that is non empty" do
    it "should verify that property.insync? of nil or :absent is false" do
      [inherit, ip, dataset].each do |prop|
        prop.stubs(:should).returns ['a','b']
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(nil).should be_false
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(:absent).should be_false
      end
    end
  end
  describe  "when trying to set a property that is non empty" do
    it "insync? should return true or false depending on the current value, and new value" do
      [inherit, ip, dataset].each do |prop|
        prop.stubs(:should).returns ['a','b']
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(['b', 'a']).should be_true
      end
      [inherit, ip, dataset].each do |prop|
        prop.insync?(['a']).should be_false
      end
    end
  end

  it "should be valid when only :path is given" do
    described_class.new(:name => "dummy", :path => '/dummy', :provider => :solaris)
  end

  it "should be invalid when :ip is missing a \":\" and iptype is :shared" do
    expect {
      described_class.new(:name => "dummy", :ip => "if", :path => "/dummy", :provider => :solaris)
    }.to raise_error(Puppet::Error, /ip must contain interface name and ip address separated by a ":"/)
  end

  it "should be invalid when :ip has a \":\" and iptype is :exclusive" do
    expect {
      described_class.new(:name => "dummy", :ip => "if:1.2.3.4", :iptype => :exclusive, :provider => :solaris)
    }.to raise_error(Puppet::Error, /only interface may be specified when using exclusive IP stack/)
  end

  it "should be invalid when :ip has two \":\" and iptype is :exclusive" do
    expect {
      described_class.new(:name => "dummy", :ip => "if:1.2.3.4:2.3.4.5", :iptype => :exclusive, :provider => :solaris)
    }.to raise_error(Puppet::Error, /only interface may be specified when using exclusive IP stack/)
  end

  it "should be valid when :iptype is :shared and using interface and ip" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4", :provider => :solaris)
  end

  it "should be valid when :iptype is :shared and using interface, ip and default route" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if:1.2.3.4:2.3.4.5", :provider => :solaris)
  end

  it "should be valid when :iptype is :exclusive and using interface" do
    described_class.new(:name => "dummy", :path => "/dummy", :ip => "if", :iptype => :exclusive, :provider => :solaris)
  end

  it "should auto-require :dataset entries" do
    fs = 'random-pool/some-zfs'

    catalog = Puppet::Resource::Catalog.new
    relationship_graph = Puppet::Graph::RelationshipGraph.new(Puppet::Graph::RandomPrioritizer.new)
    zfs = Puppet::Type.type(:zfs).new(:name => fs)
    catalog.add_resource zfs

    zone = described_class.new(:name    => "dummy",
                               :path    => "/foo",
                               :ip      => 'en1:1.0.0.0',
                               :dataset => fs,
                               :provider => :solaris)
    catalog.add_resource zone


    relationship_graph.populate_from(catalog)
    relationship_graph.dependencies(zone).should == [zfs]
  end
  describe Puppet::Zone::StateMachine do
    let (:sm) { Puppet::Zone::StateMachine.new }
    before :each do
      sm.insert_state :absent, :down => :destroy
      sm.insert_state :configured, :up => :configure, :down => :uninstall
      sm.insert_state :installed, :up => :install, :down => :stop
      sm.insert_state :running, :up => :start
    end

    context ":insert_state" do
      it "should insert state in correct order" do
        sm.insert_state :dummy, :left => :right
        sm.index(:dummy).should == 4
      end
    end
    context ":alias_state" do
      it "should alias state" do
        sm.alias_state :dummy, :running
        sm.name(:dummy).should == :running
      end
    end
    context ":name" do
      it "should get an aliased state correctly" do
        sm.alias_state :dummy, :running
        sm.name(:dummy).should == :running
      end
      it "should get an un aliased state correctly" do
        sm.name(:dummy).should == :dummy
      end
    end
    context ":index" do
      it "should return the state index correctly" do
        sm.insert_state :dummy, :left => :right
        sm.index(:dummy).should == 4
      end
    end
    context ":sequence" do
      it "should correctly return the actions to reach state specified" do
        sm.sequence(:absent, :running).map{|p|p[:up]}.should ==  [:configure,:install,:start]
      end
      it "should correctly return the actions to reach state specified(2)" do
        sm.sequence(:running, :absent).map{|p|p[:down]}.should == [:stop, :uninstall, :destroy]
      end
    end
    context ":cmp" do
      it "should correctly compare state sequence values" do
        sm.cmp?(:absent, :running).should == true
        sm.cmp?(:running, :running).should == false
        sm.cmp?(:running, :absent).should == false
      end
    end
  end
end
