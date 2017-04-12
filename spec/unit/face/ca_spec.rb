#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:ca, '0.1.0'] do
  it "should be deprecated" do
    expect(subject.deprecated?).to be_truthy
  end
end

