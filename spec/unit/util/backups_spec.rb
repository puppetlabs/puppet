#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/backups'

describe Puppet::Util::Backups do
  include PuppetSpec::Files

  before do
    FileTest.stubs(:exists?).returns true
    @nosuchfile = make_absolute('/no/such/file')
  end

  describe "when backing up a file" do
    it "should noop if the file does not exist" do
      FileTest.expects(:exists?).returns false
      file = Puppet::Type.type(:file).new(:name => @nosuchfile)
      file.expects(:bucket).never

      file.perform_backup
    end

    it "should succeed silently if self[:backup] is false" do
      file = Puppet::Type.type(:file).new(:name => @nosuchfile, :backup => false)
      file.expects(:bucket).never
      FileTest.expects(:exists?).never
      file.perform_backup
    end

    it "a bucket should be used when provided" do
      path = make_absolute('/my/file')

      File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'file'))

      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo')
      bucket = stub('bucket', 'name' => 'foo')
      file.stubs(:bucket).returns bucket

      bucket.expects(:backup).with(path).returns("mysum")

      file.perform_backup
    end

    it "should propagate any exceptions encountered when backing up to a filebucket" do
      path = make_absolute('/my/file')

      File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'file'))

      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo')
      bucket = stub('bucket', 'name' => 'foo')
      file.stubs(:bucket).returns bucket

      bucket.expects(:backup).raises ArgumentError

      lambda { file.perform_backup }.should raise_error(ArgumentError)
    end

    describe "and no filebucket is configured" do
      it "should remove any local backup if one exists" do
        path = make_absolute('/my/file')
        FileTest.stubs(:exists?).returns true

        backup = path + ".foo"

        File.expects(:lstat).with(backup).returns stub("stat", :ftype => "file")
        File.expects(:unlink).with(backup)

        FileUtils.stubs(:cp_r)

        file = Puppet::Type.type(:file).new(:name => path, :backup => '.foo')
        file.perform_backup
      end

      it "should fail when the old backup can't be removed" do
        path = make_absolute('/my/file')
        FileTest.stubs(:exists?).returns true

        backup = path + ".foo"

        File.expects(:lstat).with(backup).returns stub("stat", :ftype => "file")
        File.expects(:unlink).raises ArgumentError

        FileUtils.expects(:cp_r).never

        file = Puppet::Type.type(:file).new(:name => path, :backup => '.foo')
        lambda { file.perform_backup }.should raise_error(Puppet::Error)
      end

      it "should not try to remove backups that don't exist" do
        path = make_absolute('/my/file')
        FileTest.stubs(:exists?).returns true

        backup = path + ".foo"

        File.expects(:lstat).with(backup).raises(Errno::ENOENT)
        File.expects(:unlink).never

        FileUtils.stubs(:cp_r)

        file = Puppet::Type.type(:file).new(:name => path, :backup => '.foo')
        file.perform_backup
      end

      it "a copy should be created in the local directory" do
        path = make_absolute('/my/file')
        FileTest.stubs(:exists?).with(path).returns true

        FileUtils.expects(:cp_r).with(path, path + ".foo", :preserve => true)

        file = Puppet::Type.type(:file).new(:name => path, :backup => '.foo')
        file.perform_backup.should be_true
      end

      it "should propagate exceptions if no backup can be created" do
        path = make_absolute('/my/file')
        FileTest.stubs(:exists?).with(path).returns true

        FileUtils.expects(:cp_r).raises ArgumentError

        file = Puppet::Type.type(:file).new(:name => path, :backup => '.foo')
        lambda { file.perform_backup }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when backing up a directory" do
    it "a bucket should work when provided" do
      path = make_absolute('/my/dir')

      File.stubs(:file?).returns true
      Find.expects(:find).with(path).yields(make_absolute("/my/dir/file"))

      bucket = stub('bucket', :name => "eh")
      bucket.expects(:backup).with(make_absolute("/my/dir/file")).returns true

      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo')
      file.stubs(:bucket).returns bucket

      File.stubs(:stat).with(path).returns(stub('stat', :ftype => 'directory'))

      file.perform_backup
    end

    it "should do nothing when recursing" do
      path = make_absolute('/my/dir')

      bucket = stub('bucket', :name => "eh")
      bucket.expects(:backup).never

      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo', :recurse => true)
      file.stubs(:bucket).returns bucket

      File.stubs(:stat).with(path).returns(stub('stat', :ftype => 'directory'))

      Find.expects(:find).never

      file.perform_backup
    end
  end
end
