#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/interface'

describe Puppet::Application::Interface do
  it "should be an application" do
    Puppet::Application::Interface.superclass.should equal(Puppet::Application)
  end
end
