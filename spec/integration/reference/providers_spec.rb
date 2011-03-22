#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'puppet/util/reference'

reference = Puppet::Util::Reference.reference(:providers)

describe reference do
  it "should exist" do
    reference.should_not be_nil
  end

  it "should be able to be rendered as markdown" do
    lambda { reference.to_markdown }.should_not raise_error
  end
end
