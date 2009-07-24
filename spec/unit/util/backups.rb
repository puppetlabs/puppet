#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/type/file'
require 'puppet/util/backups'
include PuppetTest

describe Puppet::Util::Backups do
    describe "when backing up a file" do
        it "should succeed silently if the file does not exist" do
            Puppet::Type::File.new(:name => '/no/such/file').perform_backup.should be_true
        end
        it "should succeed silently if self[:backup] is false" do
            FileTest.stubs(:exists?).returns true
            Puppet::Type::File.new(:name => '/some/file', :backup => false).perform_backup.should be_true
        end
        it "a bucket should work when provided" do
            path = '/my/file'

            FileTest.stubs(:exists?).with(path).returns true
            File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'file'))

            bucket = mock('bucket', 'name' => 'foo')
            bucket.expects(:backup).with(path)

            file = Puppet::Type::File.new(:name => path, :backup => 'foo')
            file.stubs(:bucket).returns bucket

            file.perform_backup.should be_nil
        end
        it "a local backup should work" do
            path = '/my/file'
            FileTest.stubs(:exists?).with(path).returns true

            file = Puppet::Type::File.new(:name => path, :backup => '.foo')
            file.stubs(:perform_backup_with_backuplocal).returns true
            file.perform_backup.should be_true
        end
    end
    describe "when backing up a directory" do
        it "a bucket should work when provided" do
            path = '/my/dir'

            FileTest.stubs(:exists?).with(path).returns true
            File.stubs(:stat).with(path).returns(mock('stat', :ftype => 'directory'))
            Find.stubs(:find).returns('')

            #bucket = mock('bucket', 'name' => 'foo')
            bucket = mock('bucket')
            bucket.stubs(:backup).with(path).returns true

            file = Puppet::Type::File.new(:name => path, :backup => 'foo')
            file.stubs(:bucket).returns bucket

            file.perform_backup.should be_true
        end
        it "a local backup should work" do
            path = '/my/dir'
            FileTest.stubs(:exists?).with(path).returns true

            file = Puppet::Type::File.new(:name => path, :backup => '.foo')
            file.stubs(:perform_backup_with_backuplocal).returns true
            file.perform_backup.should be_true
        end
    end
end

