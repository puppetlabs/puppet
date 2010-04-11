#!/usr/bin/env ruby

require ::File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_bucket_file/file'

describe Puppet::FileBucketFile::File do
    it "should be a subclass of the Code terminus class" do
        Puppet::FileBucketFile::File.superclass.should equal(Puppet::Indirector::Code)
    end

    it "should have documentation" do
        Puppet::FileBucketFile::File.doc.should be_instance_of(String)
    end

    describe "when initializing" do
        it "should use the filebucket settings section" do
            Puppet.settings.expects(:use).with(:filebucket)
            Puppet::FileBucketFile::File.new
        end
    end


    describe "the find_by_checksum method" do
        before do
            # this is the default from spec_helper, but it keeps getting reset at odd times
            Puppet[:bucketdir] = "/dev/null/bucket"

            @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
            @checksum = "md5:4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
            @dir = '/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0'

            @contents = "file contents"
        end

        it "should return nil if a file doesn't exist" do
            ::File.expects(:exist?).with("#{@dir}/contents").returns false

            bucketfile = Puppet::FileBucketFile::File.new.send(:find_by_checksum, "md5:#{@digest}", {})
            bucketfile.should == nil
        end

        it "should find a filebucket if the file exists" do
            ::File.expects(:exist?).with("#{@dir}/contents").returns true
            ::File.expects(:exist?).with("#{@dir}/paths").returns false
            ::File.expects(:read).with("#{@dir}/contents").returns @contents

            bucketfile = Puppet::FileBucketFile::File.new.send(:find_by_checksum, "md5:#{@digest}", {})
            bucketfile.should_not == nil
        end

        it "should load the paths" do
            paths = ["path1", "path2"]
            ::File.expects(:exist?).with("#{@dir}/contents").returns true
            ::File.expects(:exist?).with("#{@dir}/paths").returns true
            ::File.expects(:read).with("#{@dir}/contents").returns @contents

            mockfile = mock "file"
            mockfile.expects(:readlines).returns( paths )
            ::File.expects(:open).with("#{@dir}/paths").yields mockfile

            Puppet::FileBucketFile::File.new.send(:find_by_checksum, "md5:#{@digest}", {}).paths.should == paths
        end

    end

    describe "when retrieving files" do
        before :each do
            Puppet.settings.stubs(:use)
            @store = Puppet::FileBucketFile::File.new

            @digest = "70924d6fa4b2d745185fa4660703a5c0"
            @sum = stub 'sum', :name => @digest

            @dir = "/what/ever"

            Puppet.stubs(:[]).with(:bucketdir).returns(@dir)

            @contents_path = '/what/ever/7/0/9/2/4/d/6/f/70924d6fa4b2d745185fa4660703a5c0/contents'
            @paths_path    = '/what/ever/7/0/9/2/4/d/6/f/70924d6fa4b2d745185fa4660703a5c0/paths'

            @request = stub 'request', :key => "md5/#{@digest}/remote/path", :options => {}
        end

        it "should call find_by_checksum" do
            @store.expects(:find_by_checksum).with{|x,opts| x == "md5:#{@digest}"}.returns(false)
            @store.find(@request)
        end

        it "should look for the calculated path" do
            ::File.expects(:exist?).with(@contents_path).returns(false)
            @store.find(@request)
        end

        it "should return an instance of Puppet::FileBucket::File created with the content if the file exists" do
            content = "my content"
            bucketfile = stub 'bucketfile'
            bucketfile.stubs(:bucket_path)
            bucketfile.stubs(:bucket_path=)
            bucketfile.stubs(:checksum_data).returns(@digest)
            bucketfile.stubs(:checksum).returns(@checksum)

            bucketfile.expects(:contents=).with(content)
            Puppet::FileBucket::File.expects(:new).with(nil, {:checksum => "md5:#{@digest}"}).yields(bucketfile).returns(bucketfile)

            ::File.expects(:exist?).with(@contents_path).returns(true)
            ::File.expects(:exist?).with(@paths_path).returns(false)
            ::File.expects(:read).with(@contents_path).returns(content)

            @store.find(@request).should equal(bucketfile)
        end

        it "should return nil if no file is found" do
            ::File.expects(:exist?).with(@contents_path).returns(false)
            @store.find(@request).should be_nil
        end

        it "should fail intelligently if a found file cannot be read" do
            ::File.expects(:exist?).with(@contents_path).returns(true)
            ::File.expects(:read).with(@contents_path).raises(RuntimeError)
            proc { @store.find(@request) }.should raise_error(Puppet::Error)
        end

    end

    describe "when determining file paths" do
        before do
            Puppet[:bucketdir] = '/dev/null/bucketdir'
            @digest = 'DEADBEEFC0FFEE'
            @bucket = stub_everything "bucket"
            @bucket.expects(:checksum_data).returns(@digest)
        end

        it "should use the value of the :bucketdir setting as the root directory" do
            path = Puppet::FileBucketFile::File.new.send(:contents_path_for, @bucket)
            path.should =~ %r{^/dev/null/bucketdir}
        end

        it "should choose a path 8 directories deep with each directory name being the respective character in the filebucket" do
            path = Puppet::FileBucketFile::File.new.send(:contents_path_for, @bucket)
            dirs = @digest[0..7].split("").join(File::SEPARATOR)
            path.should be_include(dirs)
        end

        it "should use the full filebucket as the final directory name" do
            path = Puppet::FileBucketFile::File.new.send(:contents_path_for, @bucket)
            ::File.basename(::File.dirname(path)).should == @digest
        end

        it "should use 'contents' as the actual file name" do
            path = Puppet::FileBucketFile::File.new.send(:contents_path_for, @bucket)
            ::File.basename(path).should == "contents"
        end

        it "should use the bucketdir, the 8 sum character directories, the full filebucket, and 'contents' as the full file name" do
            path = Puppet::FileBucketFile::File.new.send(:contents_path_for, @bucket)
            path.should == ['/dev/null/bucketdir', @digest[0..7].split(""), @digest, "contents"].flatten.join(::File::SEPARATOR)
         end
    end

    describe "when saving files" do
        before do
            # this is the default from spec_helper, but it keeps getting reset at odd times
            Puppet[:bucketdir] = "/dev/null/bucket"

            @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
            @checksum = "md5:4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
            @dir = '/dev/null/bucket/4/a/8/e/c/4/f/a/4a8ec4fa5f01b4ab1a0ab8cbccb709f0'

            @contents = "file contents"

            @bucket = stub "bucket file"
            @bucket.stubs(:bucket_path)
            @bucket.stubs(:checksum_data).returns(@digest)
            @bucket.stubs(:path).returns(nil)
            @bucket.stubs(:contents).returns("file contents")
        end

        it "should save the contents to the calculated path" do
            ::File.stubs(:directory?).with(@dir).returns(true)
            ::File.expects(:exist?).with("#{@dir}/contents").returns false

            mockfile = mock "file"
            mockfile.expects(:print).with(@contents)
            ::File.expects(:open).with("#{@dir}/contents", ::File::WRONLY|::File::CREAT, 0440).yields(mockfile)

            Puppet::FileBucketFile::File.new.send(:save_to_disk, @bucket)
        end

        it "should make any directories necessary for storage" do
            FileUtils.expects(:mkdir_p).with do |arg|
                ::File.umask == 0007 and arg == @dir
            end
            ::File.expects(:directory?).with(@dir).returns(false)
            ::File.expects(:open).with("#{@dir}/contents", ::File::WRONLY|::File::CREAT, 0440)
            ::File.expects(:exist?).with("#{@dir}/contents").returns false

            Puppet::FileBucketFile::File.new.send(:save_to_disk, @bucket)
        end
    end


    describe "when verifying identical files" do
        before do
            # this is the default from spec_helper, but it keeps getting reset at odd times
            Puppet[:bucketdir] = "/dev/null/bucket"

            @digest = "4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
            @checksum = "md5:4a8ec4fa5f01b4ab1a0ab8cbccb709f0"
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


    describe "when writing to the paths file" do
        before do
            Puppet[:bucketdir] = '/dev/null/bucketdir'
            @digest = '70924d6fa4b2d745185fa4660703a5c0'
            @bucket = stub_everything "bucket"

            @paths_path    = '/dev/null/bucketdir/7/0/9/2/4/d/6/f/70924d6fa4b2d745185fa4660703a5c0/paths'

            @paths = []
            @bucket.stubs(:paths).returns(@paths)
            @bucket.stubs(:checksum_data).returns(@digest)
        end

        it "should create a file if it doesn't exist" do
            @bucket.expects(:path).returns('path/to/save').at_least_once
            File.expects(:exist?).with(@paths_path).returns(false)
            file = stub "file"
            file.expects(:puts).with('path/to/save')
            File.expects(:open).with(@paths_path, ::File::WRONLY|::File::CREAT|::File::APPEND).yields(file)

            Puppet::FileBucketFile::File.new.send(:save_path_to_paths_file, @bucket)
        end

        it "should append to a file if it exists" do
            @bucket.expects(:path).returns('path/to/save').at_least_once
            File.expects(:exist?).with(@paths_path).returns(true)
            old_file = stub "file"
            old_file.stubs(:readlines).returns []
            File.expects(:open).with(@paths_path).yields(old_file)

            file = stub "file"
            file.expects(:puts).with('path/to/save')
            File.expects(:open).with(@paths_path, ::File::WRONLY|::File::CREAT|::File::APPEND).yields(file)

            Puppet::FileBucketFile::File.new.send(:save_path_to_paths_file, @bucket)
        end

        it "should not alter a file if it already contains the path" do
            @bucket.expects(:path).returns('path/to/save').at_least_once
            File.expects(:exist?).with(@paths_path).returns(true)
            old_file = stub "file"
            old_file.stubs(:readlines).returns ["path/to/save\n"]
            File.expects(:open).with(@paths_path).yields(old_file)

            Puppet::FileBucketFile::File.new.send(:save_path_to_paths_file, @bucket)
        end

        it "should do nothing if there is no path" do
            @bucket.expects(:path).returns(nil).at_least_once

            Puppet::FileBucketFile::File.new.send(:save_path_to_paths_file, @bucket)
        end
    end

end
