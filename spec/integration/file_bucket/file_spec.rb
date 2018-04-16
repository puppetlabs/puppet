#! /usr/bin/env ruby

require 'spec_helper'

require 'puppet/file_bucket/file'

describe Puppet::FileBucket::File do
  describe "#indirection" do
    before :each do
      # Never connect to the network, no matter what
      described_class.indirection.terminus(:rest).class.any_instance.stubs(:find)
    end

    describe "when running another application" do
      {
        "md5/d41d8cd98f00b204e9800998ecf8427e" => :file,
        "filebucket://puppetmaster:8140/md5/d41d8cd98f00b204e9800998ecf8427e" => :rest,
      }.each do |key, terminus|
        it "should use the #{terminus} terminus when requesting #{key.inspect}" do
          described_class.indirection.terminus(terminus).class.any_instance.expects(:find)

          described_class.indirection.find(key)
        end
      end
    end
  end

  describe "saving binary files" do
    context "given multiple backups of identical files" do
      it "does not error given content with binary external encoding" do
        binary = "\xD1\xF2\r\n\x81NuSc\x00".force_encoding(Encoding::ASCII_8BIT)
        bucket_file = Puppet::FileBucket::File.new(binary)
        Puppet::FileBucket::File.indirection.save(bucket_file, bucket_file.name)
        Puppet::FileBucket::File.indirection.save(bucket_file, bucket_file.name)
      end

      it "also does not error if the content is reported with UTF-8 external encoding" do
        # PUP-7951 - ensure accurate size comparison across encodings If binary
        # content arrives as a string with UTF-8 default external encoding, its
        # character count might be different than the same bytes with binary
        # external encoding. Ensure our equality comparison does not fail due to this.
        # As would be the case with our friend snowman:
        # Unicode snowman \u2603 - \xE2 \x98 \x83
        # character size 1, if interpreted as UTF-8, 3 "characters" if interpreted as binary
        utf8 = "\u2603".force_encoding(Encoding::UTF_8)
        bucket_file = Puppet::FileBucket::File.new(utf8)
        Puppet::FileBucket::File.indirection.save(bucket_file, bucket_file.name)
        Puppet::FileBucket::File.indirection.save(bucket_file, bucket_file.name)
      end
    end
  end
end
