#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/instrumentation/listener'
require 'puppet/indirector/instrumentation_listener/local'

describe Puppet::Indirector::InstrumentationListener::Local do
  it "should be a subclass of the Code terminus" do
    Puppet::Indirector::InstrumentationListener::Local.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:instrumentation_listener)
    Puppet::Indirector::InstrumentationListener::Local.indirection.should equal(indirection)
  end

  it "should have its name set to :local" do
    Puppet::Indirector::InstrumentationListener::Local.name.should == :local
  end
end

describe Puppet::Indirector::InstrumentationListener::Local do
  before :each do
    Puppet::Util::Instrumentation.stubs(:listener)
    @listener = Puppet::Indirector::InstrumentationListener::Local.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe "when finding listeners" do
    it "should return a Instrumentation Listener instance matching the key" do
      Puppet::Util::Instrumentation.expects(:[]).with("me").returns(:instance)
      @listener.find(@request).should == :instance
    end
  end

  describe "when searching listeners" do
    it "should return a list of all loaded Instrumentation Listenesrs irregardless of the given key" do
      Puppet::Util::Instrumentation.expects(:listeners).returns([:instance1, :instance2])
      @listener.search(@request).should == [:instance1, :instance2]
    end
  end

  describe "when saving listeners" do
    it "should set the new listener to the global listener list" do
      newlistener = stub 'listener', :name => @name
      @request.stubs(:instance).returns(newlistener)
      Puppet::Util::Instrumentation.expects(:[]=).with("me", newlistener)
      @listener.save(@request)
    end
  end

  describe "when destroying listeners" do
    it "should raise an error if listener wasn't subscribed" do
      Puppet::Util::Instrumentation.expects(:[]).with("me").returns(nil)
      lambda { @listener.destroy(@request) }.should raise_error
    end

    it "should unsubscribe the listener" do
      Puppet::Util::Instrumentation.expects(:[]).with("me").returns(:instancce)
      Puppet::Util::Instrumentation.expects(:unsubscribe).with(:instancce)
      @listener.destroy(@request)
    end
  end
end
