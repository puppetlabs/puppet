#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/file_bucket/file'
require 'digest/md5'
require 'digest/sha1'

describe Puppet::FileBucket::File do
  include PuppetSpec::Files

  let(:contents) { "file\r\n contents" }
  let(:digest) { "8b3702ad1aed1ace7e32bde76ffffb2d" }
  let(:checksum) { "{md5}#{digest}" }
  # this is the default from spec_helper, but it keeps getting reset at odd times
  let(:bucketdir) { Puppet[:bucketdir] = tmpdir('bucket') }
  let(:destdir) { File.join(bucketdir, "8/b/3/7/0/2/a/d/#{digest}") }

  it "defines its supported format to be `:s`" do
    expect(Puppet::FileBucket::File.supported_formats).to eq([:s])
  end

  it "serializes to `:s`" do
    expect(Puppet::FileBucket::File.new(contents).to_s).to eq(contents)
  end

  it "deserializes from `:s`" do
    file = Puppet::FileBucket::File.from_s(contents)

    expect(file.contents).to eq(contents)
  end

  it "should raise an error if changing content" do
    x = Puppet::FileBucket::File.new("first")
    expect { x.contents = "new" }.to raise_error(NoMethodError, /undefined method .contents=/)
  end

  it "should require contents to be a string" do
    expect { Puppet::FileBucket::File.new(5) }.to raise_error(ArgumentError, /contents must be a String, got a Fixnum$/)
  end

  it "should complain about options other than :bucket_path" do
    expect {
      Puppet::FileBucket::File.new('5', :crazy_option => 'should not be passed')
    }.to raise_error(ArgumentError, /Unknown option\(s\): crazy_option/)
  end

  it "should set the contents appropriately" do
    Puppet::FileBucket::File.new(contents).contents.should == contents
  end

  it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
    Puppet::FileBucket::File.new(contents).checksum_type.should == "md5"
  end

  it "should calculate the checksum" do
    Puppet::FileBucket::File.new(contents).checksum.should == checksum
  end

  describe "when using back-ends" do
    it "should redirect using Puppet::Indirector" do
      Puppet::Indirector::Indirection.instance(:file_bucket_file).model.should equal(Puppet::FileBucket::File)
    end

    it "should have a :save instance method" do
      Puppet::FileBucket::File.indirection.should respond_to(:save)
    end
  end

  it "should return a url-ish name" do
    Puppet::FileBucket::File.new(contents).name.should == "md5/#{digest}"
  end

  it "should reject a url-ish name with an invalid checksum" do
    bucket = Puppet::FileBucket::File.new(contents)
    expect { bucket.name = "sha1/ae548c0cd614fb7885aaa0b6cb191c34/new/path" }.to raise_error(NoMethodError, /undefined method .name=/)
  end

  it "should convert the contents to PSON" do
    # The model class no longer defines to_pson and it is not a supported
    # format, but pson monkey patches Object#to_pson to return
    # Object#to_s.to_pson, and it monkey patches String#to_pson to wrap the
    # returned string in quotes. So it works in a way that is completely
    # unexpected, and it doesn't round-trip correctly, awesome.
    Puppet::FileBucket::File.new("file contents").to_pson.should == '"file contents"'
  end

  it "should load from PSON" do
    Puppet.expects(:deprecation_warning).with('Deserializing Puppet::FileBucket::File objects from pson is deprecated. Upgrade to a newer version.')
    Puppet::FileBucket::File.from_pson({"contents"=>"file contents"}).contents.should == "file contents"
  end

  def make_bucketed_file
    FileUtils.mkdir_p(destdir)
    File.open("#{destdir}/contents", 'wb') { |f| f.write contents }
  end

  describe "using the indirector's find method" do
    it "should return nil if a file doesn't exist" do
      bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
      bucketfile.should == nil
    end

    it "should find a filebucket if the file exists" do
      make_bucketed_file
      bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
      bucketfile.checksum.should == checksum
    end

    describe "using RESTish digest notation" do
      it "should return nil if a file doesn't exist" do
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
        bucketfile.should == nil
      end

      it "should find a filebucket if the file exists" do
        make_bucketed_file
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{digest}")
        bucketfile.checksum.should == checksum
      end
    end
  end
end
