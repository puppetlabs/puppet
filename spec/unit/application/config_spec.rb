#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/application/config'

describe Puppet::Application::Config do
  it "should be a subclass of Puppet::Application::FaceBase" do
    Puppet::Application::Config.superclass.should equal(Puppet::Application::FaceBase)
  end
end
