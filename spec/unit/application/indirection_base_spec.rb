#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/application/indirection_base'
require 'puppet/face/indirector'

########################################################################
# Stub for testing; the names are critical, sadly. --daniel 2011-03-30
class Puppet::Application::TestIndirection < Puppet::Application::IndirectionBase
end

face = Puppet::Face::Indirector.define(:testindirection, '0.0.1') do
end
# REVISIT: This horror is required because we don't allow anything to be
# :current except for if it lives on, and is loaded from, disk. --daniel 2011-03-29
face.instance_variable_set('@version', :current)
Puppet::Face.register(face)
########################################################################


describe Puppet::Application::IndirectionBase do
  subject { Puppet::Application::TestIndirection.new }

  it "should accept a terminus command line option" do
    # It would be nice not to have to stub this, but whatever... writing an
    # entire indirection stack would cause us more grief. --daniel 2011-03-31
    terminus = stub_everything("test indirection terminus")
    Puppet::Indirector::Indirection.expects(:instance).
      with(:testindirection).returns(terminus)

    subject.command_line.instance_variable_set('@args', %w{--terminus foo save})

    # Not a very nice thing. :(
    $stderr.stubs(:puts)

    expect { subject.run }.should raise_error SystemExit
  end
end
