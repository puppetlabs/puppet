#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:ctime) do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before do
    @filename = tmpfile('ctime')
    @resource = Puppet::Type.type(:file).new({:name => @filename})
  end

  it "should prevent the user from trying to set the ctime" do
    expect {
      @resource[:ctime] = Time.now.to_s
    }.to raise_error(Puppet::Error, /ctime is read-only/)
  end

end
