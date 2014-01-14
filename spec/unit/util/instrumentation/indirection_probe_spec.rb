#! /usr/bin/env ruby

require 'spec_helper'
require 'matchers/json'
require 'puppet/util/instrumentation'
require 'puppet/util/instrumentation/indirection_probe'

describe Puppet::Util::Instrumentation::IndirectionProbe do
  include JSONMatchers

  Puppet::Util::Instrumentation::IndirectionProbe

  it "should indirect instrumentation_probe" do
    Puppet::Util::Instrumentation::IndirectionProbe.indirection.name.should == :instrumentation_probe
  end

  it "should return pson data" do
    probe = Puppet::Util::Instrumentation::IndirectionProbe.new("probe")
    probe.should set_json_attribute('name').to("probe")
  end
end
