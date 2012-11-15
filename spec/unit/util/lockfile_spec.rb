#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/lockfile'

describe Puppet::Util::Lockfile do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::Lockfile.new(@lockfile)
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

    it "should create a lock file containing a string" do
      data = "foofoo barbar"
      @lock.lock(data)

      File.read(@lockfile).should == data
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

  it "should return the lock data" do
    data = "foofoo barbar"
    @lock.lock(data)
    @lock.lock_data.should == data
  end
end
