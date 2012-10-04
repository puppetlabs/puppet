#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/application/indirection_base'
require 'puppet/indirector/face'

########################################################################
# Stub for testing; the names are critical, sadly. --daniel 2011-03-30
class Puppet::Application::TestIndirection < Puppet::Application::IndirectionBase
end

face = Puppet::Indirector::Face.define(:test_indirection, '0.0.1') do
  summary "fake summary"
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"
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
    terminus.stubs(:name).returns(:test_indirection)

    # This is necessary because Instrumentation tickles indirection, which
    #  messes up our expectations.
    Puppet::Util::Instrumentation.stubs(:init)

    Puppet::Indirector::Indirection.expects(:instance).
      with(:test_indirection).returns(terminus)

    subject.command_line.instance_variable_set('@args', %w{--terminus foo save bar})

    # Not a very nice thing. :(
    $stderr.stubs(:puts)
    Puppet.stubs(:err)

    expect {
      subject.run
    }.to exit_with 0
  end
end
