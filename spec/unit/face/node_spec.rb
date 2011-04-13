#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Face[:node, '0.0.1'] do
  it "should set its default format to :yaml" do
    subject.default_format.should == :yaml
  end
end
