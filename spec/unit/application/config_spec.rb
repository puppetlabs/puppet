#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/application/config'

describe Puppet::Application::Config do
  it "should be a subclass of Puppet::Application::FacesBase" do
    Puppet::Application::Config.superclass.should equal(Puppet::Application::FacesBase)
  end
end
