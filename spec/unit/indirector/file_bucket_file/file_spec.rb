#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_bucket_file/file'

describe Puppet::FileBucketFile::File do
  include PuppetSpec::Files

  it "should be a subclass of the Code terminus class" do
    Puppet::FileBucketFile::File.superclass.should equal(Puppet::Indirector::Code)
  end

  it "should have documentation" do
    Puppet::FileBucketFile::File.doc.should be_instance_of(String)
  end

  describe "non-stubbing tests" do
    include PuppetSpec::Files

    before do
      Puppet[:bucketdir] = tmpdir('bucketdir')
    end

    describe "when diffing files" do
      def save_bucket_file(contents)
        bucket_file = Puppet::FileBucket::File.new(contents)
        Puppet::FileBucket::File.indirection.save(bucket_file)
        bucket_file.checksum_data
      end

      it "should generate an empty string if there is no diff" do
        checksum = save_bucket_file("I'm the contents of a file")
        Puppet::FileBucket::File.indirection.find("md5/#{checksum}", :diff_with => checksum).should == ''
      end

      it "should generate a proper diff if there is a diff" do
        checksum1 = save_bucket_file("foo\nbar\nbaz")
        checksum2 = save_bucket_file("foo\nbiz\nbaz")
        diff = Puppet::FileBucket::File.indirection.find("md5/#{checksum1}", :diff_with => checksum2)
        diff.should == <<HERE
2c2
< bar
---
> biz
HERE
      end

      it "should raise an exception if the hash to diff against isn't found" do
        checksum = save_bucket_file("whatever")
        bogus_checksum = "d1bf072d0e2c6e20e3fbd23f022089a1"
        lambda { Puppet::FileBucket::File.indirection.find("md5/#{checksum}", :diff_with => bogus_checksum) }.should raise_error "could not find diff_with #{bogus_checksum}"
      end

      it "should return nil if the hash to diff from isn't found" do
        checksum = save_bucket_file("whatever")
        bogus_checksum = "d1bf072d0e2c6e20e3fbd23f022089a1"
        Puppet::FileBucket::File.indirection.find("md5/#{bogus_checksum}", :diff_with => checksum).should == nil
      end
    end
  end

  describe "when initializing" do
    it "should use the filebucket settings section" do
      Puppet.settings.expects(:use).with(:filebucket)
      Puppet::FileBucketFile::File.new
    end
  end


  [true, false].each do |override_bucket_path|
    describe "when bucket path #{if override_bucket_path then 'is' else 'is not' end} overridden" do
      [true, false].each do |supply_path|
        describe "when #{supply_path ? 'supplying' : 'not supplying'} a path" do
          before :each do
            Puppet.settings.stubs(:use)
            @store = Puppet::FileBucketFile::File.new
            @contents = "my content"

            @digest = "f2bfa7fc155c4f42cb91404198dda01f"
            @digest.should == Digest::MD5.hexdigest(@contents)

            @bucket_dir = tmpdir("bucket")

            if override_bucket_path
              Puppet[:bucketdir] = "/bogus/path" # should not be used
            else
              Puppet[:bucketdir] = @bucket_dir
            end

            @dir = "#{@bucket_dir}/f/2/b/f/a/7/f/c/f2bfa7fc155c4f42cb91404198dda01f"
            @contents_path = "#{@dir}/contents"
          end

          describe "when retrieving files" do
            before :each do

              request_options = {}
              if override_bucket_path
                request_options[:bucket_path] = @bucket_dir
              end

              key = "md5/#{@digest}"
              if supply_path
                key += "//path/to/file"
              end

              @request = Puppet::Indirector::Request.new(:indirection_name, :find, key, request_options)
            end

            def make_bucketed_file
              FileUtils.mkdir_p(@dir)
              File.open(@contents_path, 'w') { |f| f.write @contents }
            end

            it "should return an instance of Puppet::FileBucket::File created with the content if the file exists" do
              make_bucketed_file

              bucketfile = @store.find(@request)
              bucketfile.should be_a(Puppet::FileBucket::File)
              bucketfile.contents.should == @contents
              @store.head(@request).should == true
            end

            it "should return nil if no file is found" do
              @store.find(@request).should be_nil
              @store.head(@request).should == false
            end
          end

          describe "when saving files" do
            it "should save the contents to the calculated path" do
              options = {}
              if override_bucket_path
                options[:bucket_path] = @bucket_dir
              end

              key = "md5/#{@digest}"
              if supply_path
                key += "//path/to/file"
              end

              file_instance = Puppet::FileBucket::File.new(@contents, options)
              request = Puppet::Indirector::Request.new(:indirection_name, :save, key, file_instance)

              @store.save(request)
              File.read("#{@dir}/contents").should == @contents
            end
          end
        end
      end
    end
  end

  describe "when verifying identical files" do
    before do
      # this is the default from spec_helper, but it keeps getting reset at odd times
      Puppet[:bucketdir] = "/dev/null/bucket"

      @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
      @checksum = "{md5}4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
      @dir = '/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0'

      @contents = "file contents"

      @bucket = stub "bucket file"
      @bucket.stubs(:bucket_path)
      @bucket.stubs(:checksum).returns(@checksum)
      @bucket.stubs(:checksum_data).returns(@digest)
      @bucket.stubs(:path).returns(nil)
      @bucket.stubs(:contents).returns("file contents")
    end

    it "should raise an error if the files don't match" do
      File.expects(:read).with("#{@dir}/contents").returns("corrupt contents")
      lambda{ Puppet::FileBucketFile::File.new.send(:verify_identical_file!, @bucket) }.should raise_error(Puppet::FileBucket::BucketError)
    end

    it "should do nothing if the files match" do
      File.expects(:read).with("#{@dir}/contents").returns("file contents")
      Puppet::FileBucketFile::File.new.send(:verify_identical_file!, @bucket)
    end

  end
end
