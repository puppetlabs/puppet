#! /usr/bin/env ruby

require 'spec_helper'

require 'puppet/file_bucket/file'
require 'tempfile'

describe Puppet::FileBucket::File do
  describe "#indirection" do
    before :each do
      # Never connect to the network, no matter what
      described_class.indirection.terminus(:rest).class.any_instance.stubs(:find)
    end

    describe "when running the master application" do
      before :each do
        Puppet::Application[:master].setup_terminuses
      end

      {
        "md5/d41d8cd98f00b204e9800998ecf8427e" => :file,
        "https://puppetmaster:8140/production/file_bucket_file/md5/d41d8cd98f00b204e9800998ecf8427e" => :file,
      }.each do |key, terminus|
        it "should use the #{terminus} terminus when requesting #{key.inspect}" do
          described_class.indirection.terminus(terminus).class.any_instance.expects(:find)

          described_class.indirection.find(key)
        end
      end
    end

    describe "when running another application" do
      {
        "md5/d41d8cd98f00b204e9800998ecf8427e" => :file,
        "https://puppetmaster:8140/production/file_bucket_file/md5/d41d8cd98f00b204e9800998ecf8427e" => :rest,
      }.each do |key, terminus|
        it "should use the #{terminus} terminus when requesting #{key.inspect}" do
          described_class.indirection.terminus(terminus).class.any_instance.expects(:find)

          described_class.indirection.find(key)
        end
      end
    end
  end

  describe "#verify_identical_file!" do
    subject { Puppet::FileBucketFile::File.new }
    let(:binary) { "\xD1\xF2\r\n\x81NuSc\x00".force_encoding(Encoding::ASCII_8BIT) }

    let(:contents_file) do
      tf = Tempfile.new("hello")
      tf.write(binary)
      tf.close
      tf.path
    end

    let(:bucket_file) do
      stub(
        :stream   => StringIO.new(binary),
        :contents => binary,
        :checksum => nil)
    end

    it "must be identical for binary files" do
      subject.send :verify_identical_file!, contents_file, bucket_file
    end
  end
end
