#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/file_bucket/file'


describe Puppet::FileBucket::File, :uses_checksums => true do
  include PuppetSpec::Files

  # this is the default from spec_helper, but it keeps getting reset at odd times
  let(:bucketdir) { Puppet[:bucketdir] = tmpdir('bucket') }

  it "defaults to serializing to `:pson`" do
    expect(Puppet::FileBucket::File.default_format).to eq(:pson)
  end

  it "accepts pson" do
    expect(Puppet::FileBucket::File.supported_formats).to include(:pson)
  end

  describe "making round trips through network formats" do
    with_digest_algorithms do
      it "can make a round trip through `pson`" do
        file = Puppet::FileBucket::File.new("production", plaintext)
        tripped = Puppet::FileBucket::File.convert_from(:pson, file.render)
        expect(tripped.contents).to eq(plaintext)
      end
    end
  end

  it "should require contents to be a string" do
    expect { Puppet::FileBucket::File.new("production", 5) }.to raise_error(ArgumentError, /contents must be a String or Pathname, got a Fixnum$/)
  end

  it "should complain about options other than :bucket_path" do
    expect {
      Puppet::FileBucket::File.new("production", '5', :crazy_option => 'should not be passed')
    }.to raise_error(ArgumentError, /Unknown option\(s\): crazy_option/)
  end

  with_digest_algorithms do
    it "it uses #{metadata[:digest_algorithm]} as the configured digest algorithm" do
      file = Puppet::FileBucket::File.new("production", plaintext)

      file.contents.should == plaintext
      file.checksum_type.should == digest_algorithm
      file.checksum.should == "{#{digest_algorithm}}#{checksum}"
      file.name.should == "#{digest_algorithm}/#{checksum}"
    end
  end

  describe "when using back-ends" do
    it "should redirect using Puppet::Indirector" do
      Puppet::Indirector::Indirection.instance(:file_bucket_file).model.should equal(Puppet::FileBucket::File)
    end

    it "should have a :save instance method" do
      Puppet::FileBucket::File.indirection.should respond_to(:save)
    end
  end
end
