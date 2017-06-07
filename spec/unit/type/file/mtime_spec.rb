#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:mtime) do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before do
    @filename = tmpfile('mtime')
    @resource = Puppet::Type.type(:file).new({:name => @filename})
  end

  it "should prevent the user from trying to set the mtime" do
    expect {
      @resource[:mtime] = Time.now.to_s
    }.to raise_error(Puppet::Error, /mtime is read-only/)
  end

end
