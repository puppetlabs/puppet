#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

describe Puppet::Type.type(:file).attrclass(:ctime) do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before do
    @filename = tmpfile('ctime')
    @resource = Puppet::Type.type(:file).new({:name => @filename})
  end

  it "should be able to audit the file's ctime" do
    File.open(@filename, "w"){ }

    @resource[:audit] = [:ctime]

    # this .to_resource audit behavior is magical :-(
    @resource.to_resource[:ctime].should == File.stat(@filename).ctime
  end

  it "should return absent if auditing an absent file" do
    @resource[:audit] = [:ctime]

    @resource.to_resource[:ctime].should == :absent
  end

  it "should prevent the user from trying to set the ctime" do
    lambda {
      @resource[:ctime] = Time.now.to_s
    }.should raise_error(Puppet::Error, /ctime is read-only/)
  end

end
