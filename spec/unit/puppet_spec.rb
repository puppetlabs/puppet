#!/usr/bin/env rspec"

require 'spec_helper'
require 'puppet'

describe Puppet do
  Puppet::Util::Log.eachlevel do |level|
    it "should have a method for sending '#{level}' logs" do
      Puppet.should respond_to(level)
    end
  end

  it "should be able to change the path" do
    newpath = ENV["PATH"] + ":/something/else"
    Puppet[:path] = newpath
    ENV["PATH"].should == newpath
  end
end
