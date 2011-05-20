#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/network/client'

describe Puppet::Network::Handler do
  %w{ca filebucket fileserver master report runner status}.each do |name|
    it "should have a #{name} client" do
      Puppet::Network::Handler.handler(name).should be_instance_of(Class)
    end

    it "should have a name" do
      Puppet::Network::Handler.handler(name).name.to_s.downcase.should == name.to_s.downcase
    end

    it "should have an interface" do
      Puppet::Network::Handler.handler(name).interface.should_not be_nil
    end

    it "should have a prefix for the interface" do
      Puppet::Network::Handler.handler(name).interface.prefix.should_not be_nil
    end
  end
end
