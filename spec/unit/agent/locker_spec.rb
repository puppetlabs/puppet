#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class LockerTester
  include Puppet::Agent::Locker
end

describe Puppet::Agent::Locker do
  before do
    @locker = LockerTester.new
    @locker.stubs(:lockfile_path).returns "/my/lock"
  end

  it "should use a Pidlock instance as its lockfile" do
    @locker.lockfile.should be_instance_of(Puppet::Util::Pidlock)
  end

  it "should use 'lockfile_path' to determine its lockfile path" do
    @locker.expects(:lockfile_path).returns "/my/lock"
    lock = Puppet::Util::Pidlock.new("/my/lock")
    Puppet::Util::Pidlock.expects(:new).with("/my/lock").returns lock

    @locker.lockfile
  end

  it "should reuse the same lock file each time" do
    @locker.lockfile.should equal(@locker.lockfile)
  end

  it "should have a method that yields when a lock is attained" do
    @locker.lockfile.expects(:lock).returns true

    yielded = false
    @locker.lock do
      yielded = true
    end
    yielded.should be_true
  end

  it "should return true when the lock method successfully locked" do
    @locker.lockfile.expects(:lock).returns true

    @locker.lock {}.should be_true
  end

  it "should return true when the lock method does not receive the lock" do
    @locker.lockfile.expects(:lock).returns false

    @locker.lock {}.should be_false
  end

  it "should not yield when the lock method does not receive the lock" do
    @locker.lockfile.expects(:lock).returns false

    yielded = false
    @locker.lock { yielded = true }
    yielded.should be_false
  end

  it "should not unlock when a lock was not received" do
    @locker.lockfile.expects(:lock).returns false
    @locker.lockfile.expects(:unlock).never

    @locker.lock {}
  end

  it "should unlock after yielding upon obtaining a lock" do
    @locker.lockfile.stubs(:lock).returns true
    @locker.lockfile.expects(:unlock)

    @locker.lock {}
  end

  it "should unlock after yielding upon obtaining a lock, even if the block throws an exception" do
    @locker.lockfile.stubs(:lock).returns true
    @locker.lockfile.expects(:unlock)

    lambda { @locker.lock { raise "foo" } }.should raise_error(RuntimeError)
  end

  it "should be considered running if the lockfile is locked" do
    @locker.lockfile.expects(:locked?).returns true
    @locker.should be_running
  end
end
