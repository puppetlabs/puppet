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


  ## These tests are currently very implementation-specific, and they rely heavily on
  ##  having access to the "disable_lockfile" method.  However, I've made this method private
  ##  because it really shouldn't be exposed outside of our implementation... therefore
  ##  these tests have to use a lot of ".send" calls.  They should probably be cleaned up
  ##  but for the moment I wanted to make sure not to lose any of the functionality of
  ##  the tests. --cprice 2012-04-16

  it "should use an AnonymousFilelock instance as its disable_lockfile" do
    @disabler.send(:disable_lockfile).should be_instance_of(Puppet::Util::AnonymousFilelock)
  end


  it "should use puppet's :agent_disabled_lockfile' setting to determine its lockfile path" do
    Puppet.expects(:[]).with(:agent_disabled_lockfile).returns("/my/lock.disabled")
    lock = Puppet::Util::AnonymousFilelock.new("/my/lock.disabled")
    Puppet::Util::AnonymousFilelock.expects(:new).with("/my/lock.disabled").returns lock

    @disabler.send(:disable_lockfile)
  end

  it "should reuse the same lock file each time" do
    @disabler.send(:disable_lockfile).should equal(@disabler.send(:disable_lockfile))
  end

  it "should lock the anonymous lock when disabled" do
    @disabler.send(:disable_lockfile).expects(:lock)

    @disabler.disable
  end

  it "should disable with a message" do
    @disabler.send(:disable_lockfile).expects(:lock).with("disabled because")

    @disabler.disable("disabled because")
  end

  it "should unlock the anonymous lock when enabled" do
    @disabler.send(:disable_lockfile).expects(:unlock)

    @disabler.enable
  end

  it "should check the lock if it is disabled" do
    @disabler.send(:disable_lockfile).expects(:locked?)

    @disabler.disabled?
  end

  it "should report the disable message when disabled" do
    @disabler.send(:disable_lockfile).expects(:message).returns("message")
    @disabler.disable_message.should == "message"
  end
end
