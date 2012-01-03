#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/instrumentation/listener'
require 'puppet/indirector/instrumentation_data/local'

describe Puppet::Indirector::InstrumentationData::Local do
  it "should be a subclass of the Code terminus" do
    Puppet::Indirector::InstrumentationData::Local.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:instrumentation_data)
    Puppet::Indirector::InstrumentationData::Local.indirection.should equal(indirection)
  end

  it "should have its name set to :local" do
    Puppet::Indirector::InstrumentationData::Local.name.should == :local
  end
end

describe Puppet::Indirector::InstrumentationData::Local do
  before :each do
    Puppet::Util::Instrumentation.stubs(:listener)
    @data = Puppet::Indirector::InstrumentationData::Local.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe "when finding instrumentation data" do
    it "should return a Instrumentation Data instance matching the key" do
    end
  end

  describe "when searching listeners" do
    it "should raise an error" do
      lambda { @data.search(@request) }.should raise_error(Puppet::DevError)
    end
  end

  describe "when saving listeners" do
    it "should raise an error" do
      lambda { @data.save(@request) }.should raise_error(Puppet::DevError)
    end
  end

  describe "when destroying listeners" do
    it "should raise an error" do
      lambda { @data.destroy(@reques) }.should raise_error(Puppet::DevError)
    end
  end
end
