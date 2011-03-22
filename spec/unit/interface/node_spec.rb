#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'puppet/interface/node'

describe Puppet::Interface::Indirector.interface(:node) do
  it "should set its default format to :yaml" do
    subject.default_format.should == :yaml
  end
end
