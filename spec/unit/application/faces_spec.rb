#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/string'

describe Puppet::Application::String do
  it "should be an application" do
    Puppet::Application::String.superclass.should equal(Puppet::Application)
  end
end
