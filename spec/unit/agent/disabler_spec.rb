#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class LockerTester
  include Puppet::Agent::Disabler
end

describe Puppet::Agent::Disabler do
  before do
    @locker = LockerTester.new
    @locker.stubs(:lockfile_path).returns "/my/lock"
  end

  it "should use an AnonymousFilelock instance as its disable_lockfile" do
    @locker.disable_lockfile.should be_instance_of(Puppet::Util::AnonymousFilelock)
  end

  it "should use 'lockfile_path' to determine its disable_lockfile path" do
    @locker.expects(:lockfile_path).returns "/my/lock"
    lock = Puppet::Util::AnonymousFilelock.new("/my/lock")
    Puppet::Util::AnonymousFilelock.expects(:new).with("/my/lock.disabled").returns lock

    @locker.disable_lockfile
  end

  it "should reuse the same lock file each time" do
    @locker.disable_lockfile.should equal(@locker.disable_lockfile)
  end

  it "should lock the anonymous lock when disabled" do
    @locker.disable_lockfile.expects(:lock)

    @locker.disable
  end

  it "should disable with a message" do
    @locker.disable_lockfile.expects(:lock).with("disabled because")

    @locker.disable("disabled because")
  end

  it "should unlock the anonymous lock when enabled" do
    @locker.disable_lockfile.expects(:unlock)

    @locker.enable
  end

  it "should check the lock if it is disabled" do
    @locker.disable_lockfile.expects(:locked?)

    @locker.disabled?
  end

  it "should report the disable message when disabled" do
    @locker.disable_lockfile.expects(:message).returns("message")
    @locker.disable_message.should == "message"
  end
end
