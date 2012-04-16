#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class DisablerTester
  include Puppet::Agent::Disabler
end

describe Puppet::Agent::Disabler do
  before do
    @disabler = DisablerTester.new
    @disabler.stubs(:disabled_lockfile_path).returns "/my/lock"
  end

  it "should use an AnonymousFilelock instance as its disable_lockfile" do
    @disabler.disable_lockfile.should be_instance_of(Puppet::Util::AnonymousFilelock)
  end

  it "should use 'lockfile_path' to determine its disable_lockfile path" do
    @disabler.expects(:disabled_lockfile_path).returns "/my/lock"
    lock = Puppet::Util::AnonymousFilelock.new("/my/lock")
    Puppet::Util::AnonymousFilelock.expects(:new).with("/my/lock.disabled").returns lock

    @disabler.disable_lockfile
  end

  it "should reuse the same lock file each time" do
    @disabler.disable_lockfile.should equal(@disabler.disable_lockfile)
  end

  it "should lock the anonymous lock when disabled" do
    @disabler.disable_lockfile.expects(:lock)

    @disabler.disable
  end

  it "should disable with a message" do
    @disabler.disable_lockfile.expects(:lock).with("disabled because")

    @disabler.disable("disabled because")
  end

  it "should unlock the anonymous lock when enabled" do
    @disabler.disable_lockfile.expects(:unlock)

    @disabler.enable
  end

  it "should check the lock if it is disabled" do
    @disabler.disable_lockfile.expects(:locked?)

    @disabler.disabled?
  end

  it "should report the disable message when disabled" do
    @disabler.disable_lockfile.expects(:message).returns("message")
    @disabler.disable_message.should == "message"
  end
end
