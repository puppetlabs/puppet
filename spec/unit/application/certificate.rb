#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/certificate'

describe Puppet::Application::Certificate do
  it "should be a subclass of Puppet::Application::IndirectionBase" do
    Puppet::Application::Certificate.superclass.should equal(
      Puppet::Application::IndirectionBase
    )
  end

  it "should have a 'ca' option" do
    Puppet::Application::Certificate.new.should respond_to(:handle_ca_location)
  end

  it "should set the CA location using the 'ca' option" do
    Puppet::Application::Certificate.new.handle_ca_location("local")
    Puppet::SSL::Host.indirection.terminus_class.should == :file
  end
end
