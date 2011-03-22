#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/resource'

describe Puppet::Interface.interface(:resource) do
  before do
    @interface = Puppet::Interface.interface(:resource)
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface::Indirector)
  end

  it "should refer to the 'resource' indirection" do
    @interface.indirection.name.should == :resource
  end

  [:find, :save, :search, :save].each do |method|
    it "should have  #{method} action defined" do
      @interface.should be_action(method)
    end
  end
end
