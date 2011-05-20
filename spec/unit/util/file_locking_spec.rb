#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/file_locking'

class FileLocker
  include Puppet::Util::FileLocking
end

describe Puppet::Util::FileLocking do
  it "should have a module method for getting a read lock on files" do
    Puppet::Util::FileLocking.should respond_to(:readlock)
  end

  it "should have a module method for getting a write lock on files" do
    Puppet::Util::FileLocking.should respond_to(:writelock)
  end

  it "should have an instance method for getting a read lock on files", :'fails_on_ruby_1.9.2' => true do
    FileLocker.new.private_methods.should be_include("readlock")
  end

  it "should have an instance method for getting a write lock on files", :'fails_on_ruby_1.9.2' => true do
    FileLocker.new.private_methods.should be_include("writelock")
  end

  describe "when acquiring a read lock" do
    before do
      File.stubs(:exists?).with('/file').returns true
      File.stubs(:file?).with('/file').returns true
    end

    it "should use a global shared mutex" do
      Puppet::Util.expects(:synchronize_on).with('/file',Sync::SH).once
      Puppet::Util::FileLocking.readlock '/file'
    end

    it "should use a shared lock on the file" do
      Puppet::Util.expects(:synchronize_on).with('/file',Sync::SH).yields

      fh = mock 'filehandle'
      File.expects(:open).with("/file").yields fh
      fh.expects(:lock_shared).yields "locked_fh"

      result = nil
      Puppet::Util::FileLocking.readlock('/file') { |l| result = l }
      result.should == "locked_fh"
    end

    it "should only work on regular files" do
      File.expects(:file?).with('/file').returns false
      proc { Puppet::Util::FileLocking.readlock('/file') }.should raise_error(ArgumentError)
    end

    it "should create missing files" do
      Puppet::Util.expects(:synchronize_on).with('/file',Sync::SH).yields

      File.expects(:exists?).with('/file').returns false
      File.expects(:open).with('/file').once

      Puppet::Util::FileLocking.readlock('/file')
    end
  end

  describe "when acquiring a write lock" do
    before do
      Puppet::Util.stubs(:synchronize_on).yields
      File.stubs(:file?).with('/file').returns true
      File.stubs(:exists?).with('/file').returns true
    end

    it "should fail if the parent directory does not exist" do
      FileTest.expects(:directory?).with("/my/dir").returns false
      File.stubs(:file?).with('/my/dir/file').returns true
      File.stubs(:exists?).with('/my/dir/file').returns true

      lambda { Puppet::Util::FileLocking.writelock('/my/dir/file') }.should raise_error(Puppet::DevError)
    end

    it "should use a global exclusive mutex" do
      Puppet::Util.expects(:synchronize_on).with("/file",Sync::EX)
      Puppet::Util::FileLocking.writelock '/file'
    end

    it "should use any specified mode when opening the file" do
      File.expects(:open).with("/file", File::Constants::CREAT | File::Constants::WRONLY , :mymode)

      Puppet::Util::FileLocking.writelock('/file', :mymode)
    end

    it "should use the mode of the existing file if no mode is specified" do
      File.expects(:stat).with("/file").returns(mock("stat", :mode => 0755))
      File.expects(:open).with("/file", File::Constants::CREAT | File::Constants::WRONLY, 0755)

      Puppet::Util::FileLocking.writelock('/file')
    end

    it "should use 0600 as the mode if no mode is specified and the file does not exist" do
      File.expects(:stat).raises(Errno::ENOENT)
      File.expects(:open).with("/file", File::Constants::CREAT | File::Constants::WRONLY, 0600)

      Puppet::Util::FileLocking.writelock('/file')
    end

    it "should create an exclusive file lock" do
      fh = mock 'fh'
      File.expects(:open).yields fh
      fh.expects(:lock_exclusive)

      Puppet::Util::FileLocking.writelock('/file')
    end

    it "should allow the caller to write to the locked file" do
      fh = mock 'fh'
      File.expects(:open).yields fh

      lfh = mock 'locked_filehandle'
      fh.expects(:lock_exclusive).yields(lfh)

      lfh.stubs(:seek)
      lfh.stubs(:truncate)
      lfh.expects(:print).with "foo"

      Puppet::Util::FileLocking.writelock('/file') do |f|
        f.print "foo"
      end
    end

    it "should truncate the file under an exclusive lock" do
      fh = mock 'fh'
      File.expects(:open).yields fh

      lfh = mock 'locked_filehandle'
      fh.expects(:lock_exclusive).yields(lfh)

      lfh.expects(:seek).with(0, IO::SEEK_SET)
      lfh.expects(:truncate).with(0)
      lfh.stubs(:print)

      Puppet::Util::FileLocking.writelock('/file') do |f|
        f.print "foo"
      end
    end

    it "should only work on regular files" do
      File.expects(:file?).with('/file').returns false
      proc { Puppet::Util::FileLocking.writelock('/file') }.should raise_error(ArgumentError)
    end

    it "should create missing files" do
      Puppet::Util.expects(:synchronize_on).with('/file',Sync::EX).yields

      File.expects(:exists?).with('/file').returns false
      File.expects(:open).with('/file', File::Constants::CREAT | File::Constants::WRONLY, 0600).once

      Puppet::Util::FileLocking.writelock('/file')
    end
  end
end
