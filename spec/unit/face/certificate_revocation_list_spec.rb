#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:certificate_revocation_list, '0.0.1'] do
  it "should be deprecated" do
    expect(subject.deprecated?).to be_truthy
  end
end

