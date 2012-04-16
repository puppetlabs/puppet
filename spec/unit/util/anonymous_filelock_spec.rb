#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/anonymous_filelock'

describe Puppet::Util::AnonymousFilelock do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::AnonymousFilelock.new(@lockfile)
  end

  it "should be anonymous" do
    @lock.should be_anonymous
  end

  describe "#lock" do
    it "should return false if already locked" do
      @lock.stubs(:locked?).returns(true)
      @lock.lock.should be_false
    end

    it "should return true if it successfully locked" do
      @lock.lock.should be_true
    end

    it "should create a lock file" do
      @lock.lock

      File.should be_exists(@lockfile)
    end

    it "should create a lock file containing a message" do
      @lock.lock("message")

      File.read(@lockfile).should == "message"
    end
  end

  describe "#unlock" do
    it "should return true when unlocking" do
      @lock.lock
      @lock.unlock.should be_true
    end

    it "should return false when not locked" do
      @lock.unlock.should be_false
    end

    it "should clear the lock file" do
      File.open(@lockfile, 'w') { |fd| fd.print("locked") }
      @lock.unlock
      File.should_not be_exists(@lockfile)
    end
  end

  it "should be locked when locked" do
    @lock.lock
    @lock.should be_locked
  end

  it "should not be locked when not locked" do
    @lock.should_not be_locked
  end

  it "should not be locked when unlocked" do
    @lock.lock
    @lock.unlock
    @lock.should_not be_locked
  end

  it "should return the lock message" do
    @lock.lock("lock message")
    @lock.message.should == "lock message"
  end
end