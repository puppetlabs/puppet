#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/resource_type'

describe Puppet::Interface::ResourceType do
  before do
    @interface = Puppet::Interface::ResourceType
  end

  it "should be a subclass of 'Indirection'" do
    @interface.should be_instance_of(Puppet::Interface::Indirector)
  end

  it "should refer to the 'resource_type' indirection" do
    @interface.indirection.name.should == :resource_type
  end

  [:find, :save, :search, :save].each do |method|
    it "should have  #{method} action defined" do
      @interface.should be_action(method)
    end
  end
end
