#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/pidlock'

describe Puppet::Util::Pidlock do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::Pidlock.new(@lockfile)
  end

  describe "#lock" do
    it "should not be locked at start" do
      @lock.should_not be_locked
    end

    it "should not be mine at start" do
      @lock.should_not be_mine
    end

    it "should become locked" do
      @lock.lock
      @lock.should be_locked
    end

    it "should become mine" do
      @lock.lock
      @lock.should be_mine
    end

    it "should be possible to lock multiple times" do
      @lock.lock
      lambda { @lock.lock }.should_not raise_error
    end

    it "should return true when locking" do
      @lock.lock.should be_true
    end

    it "should return true if locked by me" do
      @lock.lock
      @lock.lock.should be_true
    end

    it "should create a lock file" do
      @lock.lock
      Puppet::FileSystem.exist?(@lockfile).should be_true
    end

    it 'should create an empty lock file even when pid is missing' do
      Process.stubs(:pid).returns('')
      @lock.lock
      Puppet::FileSystem.exist?(@lock.file_path).should be_true
      Puppet::FileSystem.read(@lock.file_path).should be_empty
    end

    it 'should replace an existing empty lockfile with a pid, given a subsequent lock call made against a valid pid' do
      # empty pid results in empty lockfile
      Process.stubs(:pid).returns('')
      @lock.lock
      Puppet::FileSystem.exist?(@lock.file_path).should be_true

      # next lock call with valid pid kills existing empty lockfile
      Process.stubs(:pid).returns(1234)
      @lock.lock
      Puppet::FileSystem.exist?(@lock.file_path).should be_true
      Puppet::FileSystem.read(@lock.file_path).should == '1234'
    end

    it "should expose the lock file_path" do
      @lock.file_path.should == @lockfile
    end
  end

  describe "#unlock" do
    it "should not be locked anymore" do
      @lock.lock
      @lock.unlock
      @lock.should_not be_locked
    end

    it "should return false if not locked" do
      @lock.unlock.should be_false
    end

    it "should return true if properly unlocked" do
      @lock.lock
      @lock.unlock.should be_true
    end

    it "should get rid of the lock file" do
      @lock.lock
      @lock.unlock
      Puppet::FileSystem.exist?(@lockfile).should be_false
    end
  end

  describe "#locked?" do
    it "should return true if locked" do
      @lock.lock
      @lock.should be_locked
    end

    it "should remove the lockfile when pid is missing" do
      Process.stubs(:pid).returns('')
      @lock.lock
      @lock.locked?.should be_false
      Puppet::FileSystem.exist?(@lock.file_path).should be_false
    end
  end

  describe '#lock_pid' do
    it 'should return nil if the pid is empty' do
      # fake pid to get empty lockfile
      Process.stubs(:pid).returns('')
      @lock.lock
      @lock.lock_pid.should == nil
    end
  end

  describe "with a stale lock" do
    before(:each) do
      # fake our pid to be 1234
      Process.stubs(:pid).returns(1234)
      # lock the file
      @lock.lock
      # fake our pid to be a different pid, to simulate someone else
      #  holding the lock
      Process.stubs(:pid).returns(6789)

      Process.stubs(:kill).with(0, 6789)
      Process.stubs(:kill).with(0, 1234).raises(Errno::ESRCH)
    end

    it "should not be locked" do
      @lock.should_not be_locked
    end

    describe "#lock" do
      it "should clear stale locks" do
        @lock.locked?.should be_false
        Puppet::FileSystem.exist?(@lockfile).should be_false
      end

      it "should replace with new locks" do
        @lock.lock
        Puppet::FileSystem.exist?(@lockfile).should be_true
        @lock.lock_pid.should == 6789
        @lock.should be_mine
        @lock.should be_locked
      end
    end

    describe "#unlock" do
      it "should not be allowed" do
        @lock.unlock.should be_false
      end

      it "should not remove the lock file" do
        @lock.unlock
        Puppet::FileSystem.exist?(@lockfile).should be_true
      end
    end
  end

  describe "with another process lock" do
    before(:each) do
      # fake our pid to be 1234
      Process.stubs(:pid).returns(1234)
      # lock the file
      @lock.lock
      # fake our pid to be a different pid, to simulate someone else
      #  holding the lock
      Process.stubs(:pid).returns(6789)

      Process.stubs(:kill).with(0, 6789)
      Process.stubs(:kill).with(0, 1234)
    end

    it "should be locked" do
      @lock.should be_locked
    end

    it "should not be mine" do
      @lock.should_not be_mine
    end

    describe "#lock" do
      it "should not be possible" do
        @lock.lock.should be_false
      end

      it "should not overwrite the lock" do
        @lock.lock
        @lock.should_not be_mine
      end
    end

    describe "#unlock" do
      it "should not be possible" do
        @lock.unlock.should be_false
      end

      it "should not remove the lock file" do
        @lock.unlock
        Puppet::FileSystem.exist?(@lockfile).should be_true
      end

      it "should still not be our lock" do
        @lock.unlock
        @lock.should_not be_mine
      end
    end
  end
end
