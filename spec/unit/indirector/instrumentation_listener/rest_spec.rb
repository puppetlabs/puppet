#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/instrumentation/listener'
require 'puppet/indirector/instrumentation_listener/rest'

describe Puppet::Indirector::InstrumentationListener::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    Puppet::Indirector::InstrumentationListener::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
