#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:type) do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before do
    @filename = tmpfile('type')
    @resource = Puppet::Type.type(:file).new({:name => @filename})
  end

  it "should prevent the user from trying to set the type" do
    lambda {
      @resource[:type] = "fifo"
    }.should raise_error(Puppet::Error, /type is read-only/)
  end

end
