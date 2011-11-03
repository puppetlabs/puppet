#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_bucket_file/file'

ALGORITHMS_TO_TRY = [nil, 'md5', 'sha256']

ALGORITHMS_TO_TRY.each do |algo|
  describe "using digest_algorithm #{algo || 'nil'}" do
    include PuppetSpec::Files

    before do
      @algo = algo || 'md5'
      @plaintext = 'stuff'
      @checksums = {
        'md5'    => 'c13d88cb4cb02003daedb8a84e5d272a',
        'sha256' => '35bafb1ce99aef3ab068afbaabae8f21fd9b9f02d3a9442e364fa92c0b3eeef0',
      }
      @dirs = {
        'md5'    => 'c/1/3/d/8/8/c/b/c13d88cb4cb02003daedb8a84e5d272a',
        'sha256' => '3/5/b/a/f/b/1/c/35bafb1ce99aef3ab068afbaabae8f21fd9b9f02d3a9442e364fa92c0b3eeef0',
      }
      # plaintext is 'other stuff'
      @not_bucketed = {
        'md5'    => 'c0133c37ea4b55af2ade92e1f1337568',
        'sha256' => '71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974',
      }
      @not_bucketed_dirs = {
        'md5'    => 'c/0/1/3/3/c/3/7/c0133c37ea4b55af2ade92e1f1337568',
        'sha256' => '7/1/e/1/9/d/6/8/71e19d6834b179eff0012516fa1397c392d5644a3438644e3f23634095a84974',
      }
      def self.dir_path
        File.join(Puppet[:bucketdir], @dirs[@algo])
      end
      def self.digest *args
        myDigest = Class.new do
          include Puppet::Util::Checksums
        end
        myDigest.new.method(@algo).call *args
      end
      Puppet[:bucketdir] = tmpdir('bucketdir')
      Puppet[:digest_algorithm] = algo
    end
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

        def save_bucket_file(contents, path = "/who_cares")
          bucket_file = Puppet::FileBucket::File.new(contents)
          Puppet::FileBucket::File.indirection.save(bucket_file, "#@algo/#{digest(contents)}#{path}")
          bucket_file.checksum_data
        end

        describe "when servicing a save request" do
          describe "when supplying a path" do
            it "should store the path if not already stored" do
              checksum = save_bucket_file(@plaintext, "/foo/bar")
              dir_path = "#{Puppet[:bucketdir]}/#{@dirs[@algo]}"
              File.read("#{dir_path}/contents").should == @plaintext
              File.read("#{dir_path}/paths").should == "foo/bar\n"
            end

            it "should leave the paths file alone if the path is already stored" do
              checksum = save_bucket_file(@plaintext, "/foo/bar")
              checksum = save_bucket_file(@plaintext, "/foo/bar")
              dir_path = "#{Puppet[:bucketdir]}/#{@dirs[@algo]}"
              File.read("#{dir_path}/contents").should == @plaintext
              File.read("#{dir_path}/paths").should == "foo/bar\n"
            end

            it "should store an additional path if the new path differs from those already stored" do
              checksum = save_bucket_file(@plaintext, "/foo/bar")
              checksum = save_bucket_file(@plaintext, "/foo/baz")
              dir_path = "#{Puppet[:bucketdir]}/#{@dirs[@algo]}"
              File.read("#{dir_path}/contents").should == @plaintext
              File.read("#{dir_path}/paths").should == "foo/bar\nfoo/baz\n"
            end
          end

          describe "when not supplying a path" do
            it "should save the file and create an empty paths file" do
              checksum = save_bucket_file(@plaintext, "")
              dir_path = "#{Puppet[:bucketdir]}/#{@dirs[@algo]}"
              File.read("#{dir_path}/contents").should == @plaintext
              File.read("#{dir_path}/paths").should == ""
            end
          end
        end

        describe "when servicing a head/find request" do
          describe "when supplying a path" do
            it "should return false/nil if the file isn't bucketed" do
              Puppet::FileBucket::File.indirection.head("#@algo/#{@not_bucketed[@algo]}/foo/bar").should == false
              Puppet::FileBucket::File.indirection.find("#@algo/#{@not_bucketed[@algo]}/foo/bar").should == nil
            end

            it "should return false/nil if the file is bucketed but with a different path" do
              checksum = save_bucket_file("I'm the contents of a file", '/foo/bar')
              Puppet::FileBucket::File.indirection.head("#@algo/#{checksum}/foo/baz").should == false
              Puppet::FileBucket::File.indirection.find("#@algo/#{checksum}/foo/baz").should == nil
            end

            it "should return true/file if the file is already bucketed with the given path" do
              contents = "I'm the contents of a file"
              checksum = save_bucket_file(contents, '/foo/bar')
              Puppet::FileBucket::File.indirection.head("#@algo/#{checksum}/foo/bar").should == true
              find_result = Puppet::FileBucket::File.indirection.find("#@algo/#{checksum}/foo/bar")
              find_result.should be_a(Puppet::FileBucket::File)
              find_result.checksum.should == "{#@algo}#{checksum}"
              find_result.to_s.should == contents
            end
          end

          describe "when not supplying a path" do
            [false, true].each do |trailing_slash|
              describe "#{trailing_slash ? 'with' : 'without'} a trailing slash" do
                trailing_string = trailing_slash ? '/' : ''

                it "should return false/nil if the file isn't bucketed" do
                  Puppet::FileBucket::File.indirection.head("#@algo/#{@not_bucketed[@algo]}#{trailing_string}").should == false
                  Puppet::FileBucket::File.indirection.find("#@algo/#{@not_bucketed[@algo]}#{trailing_string}").should == nil
                end

                it "should return true/file if the file is already bucketed" do
                  contents = "I'm the contents of a file"
                  checksum = save_bucket_file(contents, '/foo/bar')
                  Puppet::FileBucket::File.indirection.head("#@algo/#{checksum}#{trailing_string}").should == true
                  find_result = Puppet::FileBucket::File.indirection.find("#@algo/#{checksum}#{trailing_string}")
                  find_result.should be_a(Puppet::FileBucket::File)
                  find_result.checksum.should == "{#@algo}#{checksum}"
                  find_result.to_s.should == contents
                end
              end
            end
          end
        end

        describe "when diffing files", :unless => Puppet.features.microsoft_windows? do
          it "should generate an empty string if there is no diff" do
            checksum = save_bucket_file("I'm the contents of a file")
            Puppet::FileBucket::File.indirection.find("#@algo/#{checksum}", :diff_with => checksum).should == ''
          end

          it "should generate a proper diff if there is a diff" do
            checksum1 = save_bucket_file("foo\nbar\nbaz")
            checksum2 = save_bucket_file("foo\nbiz\nbaz")
            diff = Puppet::FileBucket::File.indirection.find("#@algo/#{checksum1}", :diff_with => checksum2)
            diff.should == <<HERE
2c2
< bar
---
> biz
HERE
          end

          it "should raise an exception if the hash to diff against isn't found" do
            checksum = save_bucket_file("whatever")
            lambda { Puppet::FileBucket::File.indirection.find("#@algo/#{checksum}", :diff_with => @not_bucketed[@algo] ) }.should raise_error "could not find diff_with #{@not_bucketed[@algo]}"
          end

          it "should return nil if the hash to diff from isn't found" do
            checksum = save_bucket_file("whatever")
            Puppet::FileBucket::File.indirection.find("#@algo/#{@not_bucketed[@algo]}", :diff_with => checksum).should == nil
          end
        end
      end

      describe "when initializing" do
        it "should use the filebucket settings section" do
          Puppet.settings.expects(:use).with(:filebucket)
          Puppet.settings.expects(:use).with(:main)
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

                @digest = digest(@contents)
                bucket_subdir = @digest[0,8].split('').join('/')
                under_bucket_dir = bucket_subdir + '/' + @digest

                @bucket_dir = tmpdir("bucket")

                if override_bucket_path
                  Puppet[:bucketdir] = "/bogus/path" # should not be used
                else
                  Puppet[:bucketdir] = @bucket_dir
                end

                @dir = "#{@bucket_dir}/#{under_bucket_dir}"
                @contents_path = "#{@dir}/contents"
              end

              describe "when retrieving files" do
                before :each do

                  request_options = {}
                  if override_bucket_path
                    request_options[:bucket_path] = @bucket_dir
                  end

                  key = "#@algo/#{@digest}"
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

                  key = "#@algo/#{@digest}"
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
          Puppet[:bucketdir] = make_absolute("/dev/null/bucket")

          @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
          @checksum = "{md5}4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
          @dir = make_absolute('/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0')

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
  end
end
