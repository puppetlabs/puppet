#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe Puppet::Interface.interface(:node, 1) do
  it "should set its default format to :yaml" do
    subject.default_format.should == :yaml
  end
end
