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
      expect(@lock.lock).to be_truthy
    end

    it "should return false if already locked" do
      @lock.lock
      expect(@lock.lock).to be_falsey
    end

    it "should create a lock file" do
      @lock.lock

      expect(Puppet::FileSystem.exist?(@lockfile)).to be_truthy
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
        expect((results - [true]).size).to eq(forks - 1)
        expect((results - [false]).size).to eq(1)
      end
    end

    it "should create a lock file containing a string" do
      data = "foofoo barbar"
      @lock.lock(data)

      expect(File.read(@lockfile)).to eq(data)
    end
  end

  describe "#unlock" do
    it "should return true when unlocking" do
      @lock.lock
      expect(@lock.unlock).to be_truthy
    end

    it "should return false when not locked" do
      expect(@lock.unlock).to be_falsey
    end

    it "should clear the lock file" do
      File.open(@lockfile, 'w') { |fd| fd.print("locked") }
      @lock.unlock
      expect(Puppet::FileSystem.exist?(@lockfile)).to be_falsey
    end
  end

  it "should be locked when locked" do
    @lock.lock
    expect(@lock).to be_locked
  end

  it "should not be locked when not locked" do
    expect(@lock).not_to be_locked
  end

  it "should not be locked when unlocked" do
    @lock.lock
    @lock.unlock
    expect(@lock).not_to be_locked
  end

  it "should return the lock data" do
    data = "foofoo barbar"
    @lock.lock(data)
    expect(@lock.lock_data).to eq(data)
  end
end
