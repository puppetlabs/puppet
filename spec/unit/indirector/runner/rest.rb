#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/runner/rest'

describe Puppet::Agent::Runner::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Agent::Runner::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
