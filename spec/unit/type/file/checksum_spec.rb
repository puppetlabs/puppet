#! /usr/bin/env ruby
require 'spec_helper'

checksum = Puppet::Type.type(:file).attrclass(:checksum)
describe checksum do
  before do
    @path = Puppet.features.microsoft_windows? ? "c:/foo/bar" : "/foo/bar"
    @resource = Puppet::Type.type(:file).new :path => @path
    @checksum = @resource.parameter(:checksum)
  end

  it "should be a parameter" do
    checksum.superclass.must == Puppet::Parameter
  end

  it "should use its current value when asked to sum content" do
    @checksum.value = :md5lite
    @checksum.expects(:md5lite).with("foobar").returns "yay"
    @checksum.sum("foobar")
  end

  it "should use :md5 to sum when no value is set" do
    @checksum.expects(:md5).with("foobar").returns "yay"
    @checksum.sum("foobar")
  end

  it "should return the summed contents with a checksum label" do
    sum = Digest::MD5.hexdigest("foobar")
    @resource[:checksum] = :md5
    @checksum.sum("foobar").should == "{md5}#{sum}"
  end

  it "when using digest_algorithm 'sha256' should return the summed contents with a checksum label" do
    sum = Digest::SHA256.hexdigest("foobar")
    @resource[:checksum] = :sha256
    @checksum.sum("foobar").should == "{sha256}#{sum}"
  end

  it "should use :md5 as its default type" do
    @checksum.default.should == :md5
  end

  it "should use its current value when asked to sum a file's content" do
    @checksum.value = :md5lite
    @checksum.expects(:md5lite_file).with(@path).returns "yay"
    @checksum.sum_file(@path)
  end

  it "should use :md5 to sum a file when no value is set" do
    @checksum.expects(:md5_file).with(@path).returns "yay"
    @checksum.sum_file(@path)
  end

  it "should convert all sums to strings when summing files" do
    @checksum.value = :mtime
    @checksum.expects(:mtime_file).with(@path).returns Time.now
    lambda { @checksum.sum_file(@path) }.should_not raise_error
  end

  it "should return the summed contents of a file with a checksum label" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_file).returns "mysum"
    @checksum.sum_file(@path).should == "{md5}mysum"
  end

  it "should return the summed contents of a stream with a checksum label" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_stream).returns "mysum"
    @checksum.sum_stream.should == "{md5}mysum"
  end

  it "should yield the sum_stream block to the underlying checksum" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_stream).yields("something").returns("mysum")
    @checksum.sum_stream do |sum|
      sum.should == "something"
    end
  end
end
