#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/network/client'

describe Puppet::Network::Client do
  %w{ca file report runner status}.each do |name|
    it "should have a #{name} client" do
      Puppet::Network::Client.client(name).should be_instance_of(Class)
    end

    [:name, :handler, :drivername].each do |data|
      it "should have a #{data} value for the #{name} client" do
        Puppet::Network::Client.client(name).send(data).should_not be_nil
      end
    end
  end
end
