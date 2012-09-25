#! /usr/bin/env ruby -S rspec
require 'spec_helper'
require 'puppet/face'

describe "Puppet::Face[:certificate_request, '0.0.1']" do
  subject { Puppet::Face[:certificate_request, '0.0.1'] }
  it "should actually have some tests..."
end
