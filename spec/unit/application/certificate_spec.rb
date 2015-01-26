#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/application/certificate'

describe Puppet::Application::Certificate do
  it "should have a 'ca-location' option" do
    # REVISIT: This is delegated from the face, and we will have a test there,
    # so is this actually a valuable test? --daniel 2011-04-07
    subject.command_line.stubs(:args).returns %w{list}
    subject.preinit
    subject.parse_options
    expect(subject).to respond_to(:handle_ca_location)
  end

  it "should accept the ca-location option" do
    subject.command_line.stubs(:args).returns %w{--ca-location local list}
    subject.preinit
    subject.parse_options
    subject.setup
    expect(subject.arguments).to eq([{ :ca_location => "local" }])
  end
end
