#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/node'

describe Puppet::Interface.interface(:node) do
  before do
    @interface = Puppet::Interface.interface(:node)
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface::Indirector)
  end

  it "should set its default format to :yaml" do
    @interface.default_format.should == :yaml
  end

  it "should refer to the 'node' indirection" do
    @interface.indirection.name.should == :node
  end

  [:find, :save, :search, :save].each do |method|
    it "should have  #{method} action defined" do
      @interface.should be_action(method)
    end
  end
end
