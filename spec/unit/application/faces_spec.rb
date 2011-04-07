#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/faces'

describe Puppet::Application::Faces do
  it "should be an application" do
    Puppet::Application::Faces.superclass.should equal(Puppet::Application)
  end
end
