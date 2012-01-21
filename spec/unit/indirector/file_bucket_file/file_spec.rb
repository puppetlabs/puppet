#!/usr/bin/env rspec
require 'spec_helper'

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

    def save_bucket_file(contents, path = "/who_cares")
      bucket_file = Puppet::FileBucket::File.new(contents)
      Puppet::FileBucket::File.indirection.save(bucket_file, "md5/#{Digest::MD5.hexdigest(contents)}#{path}")
      bucket_file.checksum_data
    end

    describe "when servicing a save request" do
      describe "when supplying a path" do
        it "should store the path if not already stored" do
          checksum = save_bucket_file("stuff\r\n", "/foo/bar")
          dir_path = "#{Puppet[:bucketdir]}/f/c/7/7/7/c/0/b/fc777c0bc467e1ab98b4c6915af802ec"
          Puppet::Util.binread("#{dir_path}/contents").should == "stuff\r\n"
          File.read("#{dir_path}/paths").should == "foo/bar\n"
        end

        it "should leave the paths file alone if the path is already stored" do
          checksum = save_bucket_file("stuff", "/foo/bar")
          checksum = save_bucket_file("stuff", "/foo/bar")
          dir_path = "#{Puppet[:bucketdir]}/c/1/3/d/8/8/c/b/c13d88cb4cb02003daedb8a84e5d272a"
          File.read("#{dir_path}/contents").should == "stuff"
          File.read("#{dir_path}/paths").should == "foo/bar\n"
        end

        it "should store an additional path if the new path differs from those already stored" do
          checksum = save_bucket_file("stuff", "/foo/bar")
          checksum = save_bucket_file("stuff", "/foo/baz")
          dir_path = "#{Puppet[:bucketdir]}/c/1/3/d/8/8/c/b/c13d88cb4cb02003daedb8a84e5d272a"
          File.read("#{dir_path}/contents").should == "stuff"
          File.read("#{dir_path}/paths").should == "foo/bar\nfoo/baz\n"
        end
      end

      describe "when not supplying a path" do
        it "should save the file and create an empty paths file" do
          checksum = save_bucket_file("stuff", "")
          dir_path = "#{Puppet[:bucketdir]}/c/1/3/d/8/8/c/b/c13d88cb4cb02003daedb8a84e5d272a"
          File.read("#{dir_path}/contents").should == "stuff"
          File.read("#{dir_path}/paths").should == ""
        end
      end
    end

    describe "when servicing a head/find request" do
      describe "when supplying a path" do
        it "should return false/nil if the file isn't bucketed" do
          Puppet::FileBucket::File.indirection.head("md5/0ae2ec1980410229885fe72f7b44fe55/foo/bar").should == false
          Puppet::FileBucket::File.indirection.find("md5/0ae2ec1980410229885fe72f7b44fe55/foo/bar").should == nil
        end

        it "should return false/nil if the file is bucketed but with a different path" do
          checksum = save_bucket_file("I'm the contents of a file", '/foo/bar')
          Puppet::FileBucket::File.indirection.head("md5/#{checksum}/foo/baz").should == false
          Puppet::FileBucket::File.indirection.find("md5/#{checksum}/foo/baz").should == nil
        end

        it "should return true/file if the file is already bucketed with the given path" do
          contents = "I'm the contents of a file"
          checksum = save_bucket_file(contents, '/foo/bar')
          Puppet::FileBucket::File.indirection.head("md5/#{checksum}/foo/bar").should == true
          find_result = Puppet::FileBucket::File.indirection.find("md5/#{checksum}/foo/bar")
          find_result.should be_a(Puppet::FileBucket::File)
          find_result.checksum.should == "{md5}#{checksum}"
          find_result.to_s.should == contents
        end
      end

      describe "when not supplying a path" do
        [false, true].each do |trailing_slash|
          describe "#{trailing_slash ? 'with' : 'without'} a trailing slash" do
            trailing_string = trailing_slash ? '/' : ''

            it "should return false/nil if the file isn't bucketed" do
              Puppet::FileBucket::File.indirection.head("md5/0ae2ec1980410229885fe72f7b44fe55#{trailing_string}").should == false
              Puppet::FileBucket::File.indirection.find("md5/0ae2ec1980410229885fe72f7b44fe55#{trailing_string}").should == nil
            end

            it "should return true/file if the file is already bucketed" do
              contents = "I'm the contents of a file"
              checksum = save_bucket_file(contents, '/foo/bar')
              Puppet::FileBucket::File.indirection.head("md5/#{checksum}#{trailing_string}").should == true
              find_result = Puppet::FileBucket::File.indirection.find("md5/#{checksum}#{trailing_string}")
              find_result.should be_a(Puppet::FileBucket::File)
              find_result.checksum.should == "{md5}#{checksum}"
              find_result.to_s.should == contents
            end
          end
        end
      end
    end

    describe "when diffing files", :unless => Puppet.features.microsoft_windows? do
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
                key += "/path/to/file"
              end

              @request = Puppet::Indirector::Request.new(:indirection_name, :find, key, request_options)
            end

            def make_bucketed_file
              FileUtils.mkdir_p(@dir)
              File.open(@contents_path, 'w') { |f| f.write @contents }
            end

            it "should return an instance of Puppet::FileBucket::File created with the content if the file exists" do
              make_bucketed_file

              if supply_path
                @store.find(@request).should == nil
                @store.head(@request).should == false # because path didn't match
              else
                bucketfile = @store.find(@request)
                bucketfile.should be_a(Puppet::FileBucket::File)
                bucketfile.contents.should == @contents
                @store.head(@request).should == true
              end
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
    let(:contents) { "file\r\n contents" }
    let(:digest) { "8b3702ad1aed1ace7e32bde76ffffb2d" }
    let(:checksum) { "{md5}#{@digest}" }
    let(:bucketdir) { tmpdir('file_bucket_file') }
    let(:destdir) { "#{bucketdir}/8/b/3/7/0/2/a/d/8b3702ad1aed1ace7e32bde76ffffb2d" }
    let(:bucket) { Puppet::FileBucket::File.new(contents) }

    before :each do
      Puppet[:bucketdir] = bucketdir
      FileUtils.mkdir_p(destdir)
    end

    it "should raise an error if the files don't match" do
      File.open(File.join(destdir, 'contents'), 'wb') { |f| f.print "corrupt contents" }

      lambda{
        Puppet::FileBucketFile::File.new.send(:verify_identical_file!, bucket)
      }.should raise_error(Puppet::FileBucket::BucketError)
    end

    it "should do nothing if the files match" do
      File.open(File.join(destdir, 'contents'), 'wb') { |f| f.print contents }

      Puppet::FileBucketFile::File.new.send(:verify_identical_file!, bucket)
    end
  end
end
