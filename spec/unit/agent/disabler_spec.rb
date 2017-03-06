#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class DisablerTester
  include Puppet::Agent::Disabler
end

describe Puppet::Agent::Disabler do
  before do
    @disabler = DisablerTester.new
  end

  ## These tests are currently very implementation-specific, and they rely heavily on
  ##  having access to the "disable_lockfile" method.  However, I've made this method private
  ##  because it really shouldn't be exposed outside of our implementation... therefore
  ##  these tests have to use a lot of ".send" calls.  They should probably be cleaned up
  ##  but for the moment I wanted to make sure not to lose any of the functionality of
  ##  the tests. --cprice 2012-04-16

  it "should use an JsonLockfile instance as its disable_lockfile" do
    expect(@disabler.send(:disable_lockfile)).to be_instance_of(Puppet::Util::JsonLockfile)
  end

  it "should use puppet's :agent_disabled_lockfile' setting to determine its lockfile path" do
    lockfile = File.expand_path("/my/lock.disabled")
    Puppet[:agent_disabled_lockfile] = lockfile
    lock = Puppet::Util::JsonLockfile.new(lockfile)
    Puppet::Util::JsonLockfile.expects(:new).with(lockfile).returns lock

    @disabler.send(:disable_lockfile)
  end

  it "should reuse the same lock file each time" do
    expect(@disabler.send(:disable_lockfile)).to equal(@disabler.send(:disable_lockfile))
  end

  it "should lock the file when disabled" do
    @disabler.send(:disable_lockfile).expects(:lock)

    @disabler.disable
  end

  it "should unlock the file when enabled" do
    @disabler.send(:disable_lockfile).expects(:unlock)

    @disabler.enable
  end

  it "should check the lock if it is disabled" do
    @disabler.send(:disable_lockfile).expects(:locked?)

    @disabler.disabled?
  end

  it "should report the disable message when disabled" do
    Puppet[:agent_disabled_lockfile] = PuppetSpec::Files.tmpfile("lock")

    msg = "I'm busy, go away"
    @disabler.disable(msg)
    expect(@disabler.disable_message).to eq(msg)
  end
end
