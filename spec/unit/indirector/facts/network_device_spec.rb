#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device'
require 'puppet/indirector/facts/network_device'

describe Puppet::Node::Facts::NetworkDevice do
  it "should be a subclass of the Code terminus" do
    Puppet::Node::Facts::NetworkDevice.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::Node::Facts::NetworkDevice.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    Puppet::Node::Facts::NetworkDevice.indirection.should equal(indirection)
  end

  it "should have its name set to :facter" do
    Puppet::Node::Facts::NetworkDevice.name.should == :network_device
  end
end

describe Puppet::Node::Facts::NetworkDevice do
  before :each do
    @remote_device = stub 'remote_device', :facts => {}
    Puppet::Util::NetworkDevice.stubs(:current).returns(@remote_device)
    @device = Puppet::Node::Facts::NetworkDevice.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe Puppet::Node::Facts::NetworkDevice, " when finding facts" do
    it "should return a Facts instance" do
      @device.find(@request).should be_instance_of(Puppet::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      @device.find(@request).name.should == @name
    end

    it "should return the device facts as the values in the Facts instance" do
      @remote_device.expects(:facts).returns("one" => "two")
      facts = @device.find(@request)
      facts.values["one"].should == "two"
    end

    it "should add local facts" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      @device.find(@request)
    end

    it "should convert facts into strings when stringify_facts is true" do
      Puppet[:stringify_facts] = true
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:stringify)

      @device.find(@request)
    end

    it "should sanitizer facts when stringify_facts is false" do
      Puppet[:stringify_facts] = false
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:sanitize)

      @device.find(@request)
    end
  end

  describe Puppet::Node::Facts::NetworkDevice, " when saving facts" do
    it "should fail" do
      proc { @device.save(@facts) }.should raise_error(Puppet::DevError)
    end
  end

  describe Puppet::Node::Facts::NetworkDevice, " when destroying facts" do
    it "should fail" do
      proc { @device.destroy(@facts) }.should raise_error(Puppet::DevError)
    end
  end
end
