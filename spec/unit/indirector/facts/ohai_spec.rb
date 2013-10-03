#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/facts/ohai'

describe Puppet::Node::Facts::Ohai do
  it "should be a subclass of the Code terminus" do
    Puppet::Node::Facts::Ohai.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::Node::Facts::Ohai.doc.should_not be_nil
  end

  it "should be registered with the configuration store indirection" do
    indirection = Puppet::Indirector::Indirection.instance(:facts)
    Puppet::Node::Facts::Ohai.indirection.should equal(indirection)
  end

  it "should have its name set to :ohai" do
    Puppet::Node::Facts::Ohai.name.should == :ohai
  end
end

describe Puppet::Node::Facts::Ohai do
  before :each do
    @ohai = Puppet::Node::Facts::Ohai.new
    @name = "me"
    @request = stub 'request', :key => @name
  end

  describe Puppet::Node::Facts::Ohai, " when finding facts" do
    it "should return a Facts instance" do
      @ohai.find(@request).should be_instance_of(Puppet::Node::Facts)
    end

    it "should return a Facts instance with the provided key as the name" do
      @ohai.find(@request).name.should == @name
    end

    it "should add local facts" do
      facts = Puppet::Node::Facts.new("foo")
      Puppet::Node::Facts.expects(:new).returns facts
      facts.expects(:add_local_facts)

      @ohai.find(@request)
    end
  end
end
