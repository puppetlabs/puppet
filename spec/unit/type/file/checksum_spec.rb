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
    expect(checksum.superclass).to eq(Puppet::Parameter)
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
    expect(@checksum.sum("foobar")).to eq("{md5}#{sum}")
  end

  it "when using digest_algorithm 'sha256' should return the summed contents with a checksum label" do
    sum = Digest::SHA256.hexdigest("foobar")
    @resource[:checksum] = :sha256
    expect(@checksum.sum("foobar")).to eq("{sha256}#{sum}")
  end

  it "when using digest_algorithm 'sha512' should return the summed contents with a checksum label" do
    sum = Digest::SHA512.hexdigest("foobar")
    @resource[:checksum] = :sha512
    expect(@checksum.sum("foobar")).to eq("{sha512}#{sum}")
  end

  it "when using digest_algorithm 'sha384' should return the summed contents with a checksum label" do
    sum = Digest::SHA384.hexdigest("foobar")
    @resource[:checksum] = :sha384
    expect(@checksum.sum("foobar")).to eq("{sha384}#{sum}")
  end

  it "should use :md5 as its default type" do
    expect(@checksum.default).to eq(:md5)
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
    expect { @checksum.sum_file(@path) }.not_to raise_error
  end

  it "should return the summed contents of a file with a checksum label" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_file).returns "mysum"
    expect(@checksum.sum_file(@path)).to eq("{md5}mysum")
  end

  it "should return the summed contents of a stream with a checksum label" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_stream).returns "mysum"
    expect(@checksum.sum_stream).to eq("{md5}mysum")
  end

  it "should yield the sum_stream block to the underlying checksum" do
    @resource[:checksum] = :md5
    @checksum.expects(:md5_stream).yields("something").returns("mysum")
    @checksum.sum_stream do |sum|
      expect(sum).to eq("something")
    end
  end

  it 'should use values allowed by the supported_checksum_types setting' do
    values = checksum.value_collection.values.reject {|v| v == :none}.map {|v| v.to_s}
    Puppet.settings[:supported_checksum_types] = values
    expect(Puppet.settings[:supported_checksum_types]).to eq(values)
  end

  it 'rejects md5 checksums in FIPS mode' do
    Puppet::Util::Platform.stubs(:fips_enabled?).returns true
    expect {
      @resource[:checksum] = :md5
    }.to raise_error(Puppet::ResourceError,
                     /Parameter checksum failed.* MD5 is not supported in FIPS mode/)
  end
end
