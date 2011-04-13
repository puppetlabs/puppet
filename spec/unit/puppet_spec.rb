#!/usr/bin/env rspec"

require 'spec_helper'
require 'puppet'

describe Puppet do
  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      Puppet.should respond_to(level)
    end
  end
end
