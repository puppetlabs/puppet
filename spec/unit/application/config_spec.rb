#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/config'

describe Puppet::Application::Config do
  it "should be a subclass of Puppet::Application::StringBase" do
    Puppet::Application::Config.superclass.should equal(Puppet::Application::StringBase)
  end
end
