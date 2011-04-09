#!/usr/bin/env ruby

require 'spec_helper'
require 'puppet/application/faces'

describe Puppet::Application::Faces do
  it "should be an application" do
    Puppet::Application::Faces.superclass.should equal(Puppet::Application)
  end

  it "should always call 'list'" do
    faces = Puppet::Application::Faces.new
    faces.expects(:list)
    faces.main
  end
end
