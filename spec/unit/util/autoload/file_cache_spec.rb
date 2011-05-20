#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/autoload/file_cache'

class FileCacheTester
  include Puppet::Util::Autoload::FileCache
end

describe Puppet::Util::Autoload::FileCache do
  before do
    @cacher = FileCacheTester.new
  end

  after do
    Puppet::Util::Autoload::FileCache.clear
  end

  describe "when checking whether files exist" do
    it "should have a method for testing whether a file exists" do
      @cacher.should respond_to(:file_exist?)
    end

    it "should use lstat to determine whether a file exists" do
      File.expects(:lstat).with("/my/file")
      @cacher.file_exist?("/my/file")
    end

    it "should consider a file as absent if its lstat fails" do
      File.expects(:lstat).with("/my/file").raises Errno::ENOENT
      @cacher.should_not be_file_exist("/my/file")
    end

    it "should consider a file as absent if the directory is absent" do
      File.expects(:lstat).with("/my/file").raises Errno::ENOTDIR
      @cacher.should_not be_file_exist("/my/file")
    end

    it "should consider a file as absent permissions are missing" do
      File.expects(:lstat).with("/my/file").raises Errno::EACCES
      @cacher.should_not be_file_exist("/my/file")
    end

    it "should raise non-fs exceptions" do
      File.expects(:lstat).with("/my/file").raises ArgumentError
      lambda { @cacher.file_exist?("/my/file") }.should raise_error(ArgumentError)
    end

    it "should consider a file as present if its lstat succeeds" do
      File.expects(:lstat).with("/my/file").returns mock("stat")
      @cacher.should be_file_exist("/my/file")
    end

    it "should not stat a file twice in quick succession when the file is missing" do
      File.expects(:lstat).with("/my/file").once.raises Errno::ENOENT
      @cacher.should_not be_file_exist("/my/file")
      @cacher.should_not be_file_exist("/my/file")
    end

    it "should not stat a file twice in quick succession when the file is present" do
      File.expects(:lstat).with("/my/file").once.returns mock("stat")
      @cacher.should be_file_exist("/my/file")
      @cacher.should be_file_exist("/my/file")
    end

    it "should expire cached data after 15 seconds" do
      now = Time.now

      later = now + 16

      Time.expects(:now).times(3).returns(now).then.returns(later).then.returns(later)
      File.expects(:lstat).with("/my/file").times(2).returns(mock("stat")).then.raises Errno::ENOENT
      @cacher.should be_file_exist("/my/file")
      @cacher.should_not be_file_exist("/my/file")
    end

    it "should share cached data across autoload instances" do
      File.expects(:lstat).with("/my/file").once.returns mock("stat")
      other = Puppet::Util::Autoload.new("bar", "tmp")

      @cacher.should be_file_exist("/my/file")
      other.should be_file_exist("/my/file")
    end
  end

  describe "when checking whether files exist" do
    before do
      @stat = stub 'stat', :directory? => true
    end

    it "should have a method for determining whether a directory exists" do
      @cacher.should respond_to(:directory_exist?)
    end

    it "should use lstat to determine whether a directory exists" do
      File.expects(:lstat).with("/my/file").returns @stat
      @cacher.directory_exist?("/my/file")
    end

    it "should consider a directory as absent if its lstat fails" do
      File.expects(:lstat).with("/my/file").raises Errno::ENOENT
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should consider a file as absent if the directory is absent" do
      File.expects(:lstat).with("/my/file").raises Errno::ENOTDIR
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should consider a file as absent permissions are missing" do
      File.expects(:lstat).with("/my/file").raises Errno::EACCES
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should raise non-fs exceptions" do
      File.expects(:lstat).with("/my/file").raises ArgumentError
      lambda { @cacher.directory_exist?("/my/file") }.should raise_error(ArgumentError)
    end

    it "should consider a directory as present if its lstat succeeds and the stat is of a directory" do
      @stat.expects(:directory?).returns true
      File.expects(:lstat).with("/my/file").returns @stat
      @cacher.should be_directory_exist("/my/file")
    end

    it "should consider a directory as absent if its lstat succeeds and the stat is not of a directory" do
      @stat.expects(:directory?).returns false
      File.expects(:lstat).with("/my/file").returns @stat
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should not stat a directory twice in quick succession when the file is missing" do
      File.expects(:lstat).with("/my/file").once.raises Errno::ENOENT
      @cacher.should_not be_directory_exist("/my/file")
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should not stat a directory twice in quick succession when the file is present" do
      File.expects(:lstat).with("/my/file").once.returns @stat
      @cacher.should be_directory_exist("/my/file")
      @cacher.should be_directory_exist("/my/file")
    end

    it "should not consider a file to be a directory based on cached data" do
      @stat.stubs(:directory?).returns false
      File.stubs(:lstat).with("/my/file").returns @stat
      @cacher.file_exist?("/my/file")
      @cacher.should_not be_directory_exist("/my/file")
    end

    it "should share cached data across autoload instances" do
      File.expects(:lstat).with("/my/file").once.returns @stat
      other = Puppet::Util::Autoload.new("bar", "tmp")

      @cacher.should be_directory_exist("/my/file")
      other.should be_directory_exist("/my/file")
    end
  end
end
