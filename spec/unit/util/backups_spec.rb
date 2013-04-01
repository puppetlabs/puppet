#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/backups'

describe Puppet::Util::Backups do
  include PuppetSpec::Files

  let(:bucket) { stub('bucket', :name => "foo") }
  let!(:file) do
    f = Puppet::Type.type(:file).new(:name => path, :backup => 'foo')
    f.stubs(:bucket).returns(bucket)
    f
  end

  describe "when backing up a file" do
    let(:path) { make_absolute('/no/such/file') }

    it "should noop if the file does not exist" do
      file = Puppet::Type.type(:file).new(:name => path)

      file.expects(:bucket).never
      FileTest.expects(:exists?).with(path).returns false

      file.perform_backup
    end

    it "should succeed silently if self[:backup] is false" do
      file = Puppet::Type.type(:file).new(:name => path, :backup => false)

      file.expects(:bucket).never
      FileTest.expects(:exists?).never

      file.perform_backup
    end

    it "a bucket should be used when provided" do
      File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'file'))
      bucket.expects(:backup).with(path).returns("mysum")
      FileTest.expects(:exists?).with(path).returns(true)

      file.perform_backup
    end

    it "should propagate any exceptions encountered when backing up to a filebucket" do
      File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'file'))
      bucket.expects(:backup).raises ArgumentError
      FileTest.expects(:exists?).with(path).returns(true)

      lambda { file.perform_backup }.should raise_error(ArgumentError)
    end

    describe "and local backup is configured" do
      let(:ext) { 'foobkp' }
      let(:backup) { path + '.' + ext }
      let(:file) { Puppet::Type.type(:file).new(:name => path, :backup => '.'+ext) }

      it "should remove any local backup if one exists" do
        File.expects(:lstat).with(backup).returns stub("stat", :ftype => "file")
        File.expects(:unlink).with(backup)
        FileUtils.stubs(:cp_r)
        FileTest.expects(:exists?).with(path).returns(true)

        file.perform_backup
      end

      it "should fail when the old backup can't be removed" do
        File.expects(:lstat).with(backup).returns stub("stat", :ftype => "file")
        File.expects(:unlink).with(backup).raises ArgumentError
        FileUtils.expects(:cp_r).never
        FileTest.expects(:exists?).with(path).returns(true)

        lambda { file.perform_backup }.should raise_error(Puppet::Error)
      end

      it "should not try to remove backups that don't exist" do
        File.expects(:lstat).with(backup).raises(Errno::ENOENT)
        File.expects(:unlink).with(backup).never
        FileUtils.stubs(:cp_r)
        FileTest.expects(:exists?).with(path).returns(true)

        file.perform_backup
      end

      it "a copy should be created in the local directory" do
        FileUtils.expects(:cp_r).with(path, backup, :preserve => true)
        FileTest.stubs(:exists?).with(path).returns(true)

        file.perform_backup.should be_true
      end

      it "should propagate exceptions if no backup can be created" do
        FileUtils.expects(:cp_r).raises ArgumentError

        FileTest.stubs(:exists?).with(path).returns(true)
        lambda { file.perform_backup }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when backing up a directory" do
    let(:path) { make_absolute('/my/dir') }
    let(:filename) { File.join(path, 'file') }

    it "a bucket should work when provided" do
      File.stubs(:file?).with(filename).returns true
      Find.expects(:find).with(path).yields(filename)

      bucket.expects(:backup).with(filename).returns true

      File.stubs(:stat).with(path).returns(stub('stat', :ftype => 'directory'))

      FileTest.stubs(:exists?).with(path).returns(true)
      FileTest.stubs(:exists?).with(filename).returns(true)

      file.perform_backup
    end

    it "should do nothing when recursing" do
      file = Puppet::Type.type(:file).new(:name => path, :backup => 'foo', :recurse => true)

      bucket.expects(:backup).never
      File.stubs(:stat).with(path).returns(stub('stat', :ftype => 'directory'))
      Find.expects(:find).never

      file.perform_backup
    end
  end
end
