#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class LockerTester
  include Puppet::Agent::Locker
end

describe Puppet::Agent::Locker do
  before do
    @locker = LockerTester.new
  end

  ## These tests are currently very implementation-specific, and they rely heavily on
  ##  having access to the lockfile object.  However, I've made this method private
  ##  because it really shouldn't be exposed outside of our implementation... therefore
  ##  these tests have to use a lot of ".send" calls.  They should probably be cleaned up
  ##  but for the moment I wanted to make sure not to lose any of the functionality of
  ##  the tests.   --cprice 2012-04-16

  it "should use a Pidlock instance as its lockfile" do
    expect(@locker.send(:lockfile)).to be_instance_of(Puppet::Util::Pidlock)
  end

  it "should use puppet's agent_catalog_run_lockfile' setting to determine its lockfile path" do
    lockfile = File.expand_path("/my/lock")
    Puppet[:agent_catalog_run_lockfile] = lockfile
    lock = Puppet::Util::Pidlock.new(lockfile)
    Puppet::Util::Pidlock.expects(:new).with(lockfile).returns lock

    @locker.send(:lockfile)
  end

  it "#lockfile_path provides the path to the lockfile" do
    lockfile = File.expand_path("/my/lock")
    Puppet[:agent_catalog_run_lockfile] = lockfile
    expect(@locker.lockfile_path).to eq(File.expand_path("/my/lock"))
  end

  it "should reuse the same lock file each time" do
    expect(@locker.send(:lockfile)).to equal(@locker.send(:lockfile))
  end

  it "should have a method that yields when a lock is attained" do
    @locker.send(:lockfile).expects(:lock).returns true

    yielded = false
    @locker.lock do
      yielded = true
    end
    expect(yielded).to be_truthy
  end

  it "should return the block result when the lock method successfully locked" do
    @locker.send(:lockfile).expects(:lock).returns true

    expect(@locker.lock { :result }).to eq(:result)
  end

  it "should raise LockError when the lock method does not receive the lock" do
    @locker.send(:lockfile).expects(:lock).returns false

    expect { @locker.lock {} }.to raise_error(Puppet::LockError)
  end

  it "should not yield when the lock method does not receive the lock" do
    @locker.send(:lockfile).expects(:lock).returns false

    yielded = false
    expect { @locker.lock { yielded = true } }.to raise_error(Puppet::LockError)
    expect(yielded).to be_falsey
  end

  it "should not unlock when a lock was not received" do
    @locker.send(:lockfile).expects(:lock).returns false
    @locker.send(:lockfile).expects(:unlock).never

    expect { @locker.lock {} }.to raise_error(Puppet::LockError)
  end

  it "should unlock after yielding upon obtaining a lock" do
    @locker.send(:lockfile).stubs(:lock).returns true
    @locker.send(:lockfile).expects(:unlock)

    @locker.lock {}
  end

  it "should unlock after yielding upon obtaining a lock, even if the block throws an exception" do
    @locker.send(:lockfile).stubs(:lock).returns true
    @locker.send(:lockfile).expects(:unlock)

    expect { @locker.lock { raise "foo" } }.to raise_error(RuntimeError)
  end

  it "should be considered running if the lockfile is locked" do
    @locker.send(:lockfile).expects(:locked?).returns true
    expect(@locker).to be_running
  end
end
