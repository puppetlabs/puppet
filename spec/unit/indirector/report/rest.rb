#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/report/rest'

describe Puppet::Transaction::Report::Rest do
    it "should be a sublcass of Puppet::Indirector::REST" do
        Puppet::Transaction::Report::Rest.superclass.should equal(Puppet::Indirector::REST)
    end
end
