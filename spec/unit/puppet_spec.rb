#!/usr/bin/env rspec"

require 'spec_helper'
require 'puppet'
require 'puppet_spec/files'
require 'semver'

describe Puppet do
  include PuppetSpec::Files

  context "#version" do
    it "should be valid semver" do
      SemVer.should be_valid Puppet.version
    end
  end

  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      Puppet.should respond_to(level)
    end
  end
end
