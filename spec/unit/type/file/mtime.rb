#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

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
    @resource.to_resource[:mtime].should == File.stat(@filename).mtime
  end

  it "should return absent if auditing an absent file" do
    @resource[:audit] = [:mtime]

    @resource.to_resource[:mtime].should == :absent
  end

  it "should prevent the user from trying to set the mtime" do
    lambda {
      @resource[:mtime] = Time.now.to_s
    }.should raise_error(Puppet::Error, /mtime is read-only/)
  end

end
