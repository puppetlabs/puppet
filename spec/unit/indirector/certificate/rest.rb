#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/certificate/rest'

describe Puppet::SSL::Certificate::Rest do
    before do
        @searcher = Puppet::SSL::Certificate::Rest.new
    end

    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::SSL::Certificate::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
