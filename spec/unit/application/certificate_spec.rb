#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/application/certificate'

describe Puppet::Application::Certificate do
  it "should have a 'ca-location' option" do
    # REVISIT: This is delegated from the string, and we will have a test
    # there, so is this actually a valuable test?
    subject.command_line.stubs(:args).returns %w{list}
    subject.preinit
    subject.should respond_to(:handle_ca_location)
  end

  it "should accept the ca-location option" do
    subject.command_line.stubs(:args).returns %w{--ca-location local list}
    subject.preinit and subject.parse_options and subject.setup
    subject.arguments.should == [{ :ca_location => "local" }]
  end
end
