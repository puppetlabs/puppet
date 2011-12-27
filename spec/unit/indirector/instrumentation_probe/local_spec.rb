#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/instrumentation/indirection_probe'
require 'puppet/indirector/instrumentation_probe/local'
require 'puppet/util/instrumentation/instrumentable'

describe Puppet::Indirector::InstrumentationProbe::Local do
  it "should be a subclass of the Code terminus" do
    Puppet::Indirector::InstrumentationProbe::Local.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:instrumentation_probe)
    Puppet::Indirector::InstrumentationProbe::Local.indirection.should equal(indirection)
  end

  it "should have its name set to :local" do
    Puppet::Indirector::InstrumentationProbe::Local.name.should == :local
  end
end

describe Puppet::Indirector::InstrumentationProbe::Local do
  before :each do
    Puppet::Util::Instrumentation.stubs(:listener)
    @probe = Puppet::Indirector::InstrumentationProbe::Local.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe "when finding probes" do
    it "should do nothing" do
      @probe.find(@request).should be_nil
    end
  end

  describe "when searching probes" do
    it "should return a list of all loaded probes irregardless of the given key" do
      instance1 = stub 'instance1', :method => "probe1", :klass => "Klass1"
      instance2 = stub 'instance2', :method => "probe2", :klass => "Klass2"
      Puppet::Util::Instrumentation::IndirectionProbe.expects(:new).with("Klass1.probe1").returns(:instance1)
      Puppet::Util::Instrumentation::IndirectionProbe.expects(:new).with("Klass2.probe2").returns(:instance2)
      Puppet::Util::Instrumentation::Instrumentable.expects(:each_probe).multiple_yields([instance1], [instance2])
      @probe.search(@request).should == [ :instance1, :instance2 ]
    end
  end

  describe "when saving probes" do
    it "should enable probes" do
      newprobe = stub 'probe', :name => @name
      @request.stubs(:instance).returns(newprobe)
      Puppet::Util::Instrumentation::Instrumentable.expects(:enable_probes)
      @probe.save(@request)
    end
  end

  describe "when destroying probes" do
    it "should disable probes" do
      newprobe = stub 'probe', :name => @name
      @request.stubs(:instance).returns(newprobe)
      Puppet::Util::Instrumentation::Instrumentable.expects(:disable_probes)
      @probe.destroy(@request)
    end
  end
end
