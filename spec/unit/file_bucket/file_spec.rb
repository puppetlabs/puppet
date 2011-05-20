#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_bucket/file'
require 'digest/md5'
require 'digest/sha1'

describe Puppet::FileBucket::File do
  include PuppetSpec::Files

  before do
    # this is the default from spec_helper, but it keeps getting reset at odd times
    @bucketdir = tmpdir('bucket')
    Puppet[:bucketdir] = @bucketdir

    @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
    @checksum = "{md5}4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
    @dir = File.join(@bucketdir, '4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0')

    @contents = "file contents"
  end

  it "should have a to_s method to return the contents" do
    Puppet::FileBucket::File.new(@contents).to_s.should == @contents
  end

  it "should raise an error if changing content" do
    x = Puppet::FileBucket::File.new("first")
    proc { x.contents = "new" }.should raise_error
  end

  it "should require contents to be a string" do
    proc { Puppet::FileBucket::File.new(5) }.should raise_error(ArgumentError)
  end

  it "should set the contents appropriately" do
    Puppet::FileBucket::File.new(@contents).contents.should == @contents
  end

  it "should default to 'md5' as the checksum algorithm if the algorithm is not in the name" do
    Puppet::FileBucket::File.new(@contents).checksum_type.should == "md5"
  end

  it "should calculate the checksum" do
    Puppet::FileBucket::File.new(@contents).checksum.should == @checksum
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
    Puppet::FileBucket::File.new(@contents).name.should == "md5/4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
  end

  it "should reject a url-ish name with an invalid checksum" do
    bucket = Puppet::FileBucket::File.new(@contents)
    lambda { bucket.name = "sha1/4a8ec4fa5f01b4ab1a0ab8cbccb709f0/new/path" }.should raise_error
  end

  it "should convert the contents to PSON" do
    Puppet::FileBucket::File.new(@contents).to_pson.should == '{"contents":"file contents"}'
  end

  it "should load from PSON" do
    Puppet::FileBucket::File.from_pson({"contents"=>"file contents"}).contents.should == "file contents"
  end

  def make_bucketed_file
    FileUtils.mkdir_p(@dir)
    File.open("#{@dir}/contents", 'w') { |f| f.write @contents }
  end

  describe "using the indirector's find method" do
    it "should return nil if a file doesn't exist" do
      bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{@digest}")
      bucketfile.should == nil
    end

    it "should find a filebucket if the file exists" do
      make_bucketed_file
      bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{@digest}")
      bucketfile.should_not == nil
    end

    describe "using RESTish digest notation" do
      it "should return nil if a file doesn't exist" do
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{@digest}")
        bucketfile.should == nil
      end

      it "should find a filebucket if the file exists" do
        make_bucketed_file
        bucketfile = Puppet::FileBucket::File.indirection.find("md5/#{@digest}")
        bucketfile.should_not == nil
      end

    end
  end
end
