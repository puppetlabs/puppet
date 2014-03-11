#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/lockfile'

module LockfileSpecHelper
  def self.run_in_forks(count, &blk)
    forks = {}
    results = []
    count.times do |i|
      forks[i] = {}
      forks[i][:read], forks[i][:write] = IO.pipe

      forks[i][:pid] = fork do
        forks[i][:read].close
        res = yield
        Marshal.dump(res, forks[i][:write])
        exit!
      end
    end

    count.times do |i|
      forks[i][:write].close
      result = forks[i][:read].read
      forks[i][:read].close
      Process.wait2(forks[i][:pid])
      results << Marshal.load(result)
    end
    results
  end
end

describe Puppet::Util::Lockfile do
  require 'puppet_spec/files'
  include PuppetSpec::Files

  before(:each) do
    @lockfile = tmpfile("lock")
    @lock = Puppet::Util::Lockfile.new(@lockfile)
  end

  describe "#lock" do
    it "should return true if it successfully locked" do
      @lock.lock.should be_true
    end

    it "should return false if already locked" do
      @lock.lock
      @lock.lock.should be_false
    end

    it "should create a lock file" do
      @lock.lock

      Puppet::FileSystem.exist?(@lockfile).should be_true
    end

    # We test simultaneous locks using fork which isn't supported on Windows.
    it "should not be acquired by another process", :unless => Puppet.features.microsoft_windows? do
      30.times do
        forks = 3
        results = LockfileSpecHelper.run_in_forks(forks) do
          @lock.lock(Process.pid)
        end
        @lock.unlock

        # Confirm one fork returned true and everyone else false.
        (results - [true]).size.should == forks - 1
        (results - [false]).size.should == 1
      end
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
      Puppet::FileSystem.exist?(@lockfile).should be_false
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
