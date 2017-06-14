#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:file).attrclass(:mtime) do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before do
    @filename = tmpfile('mtime')
    @resource = Puppet::Type.type(:file).new({:name => @filename})
  end

  it "should be able to audit the file's mtime" do
    File.open(@filename, "w"){ }

    @resource[:audit] = [:mtime]

    # this .to_resource audit behavior is magical :-(
    expect(@resource.to_resource[:mtime]).to eq(Puppet::FileSystem.stat(@filename).mtime)
  end

  it "should return absent if auditing an absent file" do
    @resource[:audit] = [:mtime]

    expect(@resource.to_resource[:mtime]).to eq(:absent)
  end

  it "should prevent the user from trying to set the mtime" do
    expect {
      @resource[:mtime] = Time.now.to_s
    }.to raise_error(Puppet::Error, /mtime is read-only/)
  end

end
