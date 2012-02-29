#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/agent'
require 'puppet/agent/locker'

class LockerTester
  include Puppet::Agent::Disabler
end

describe Puppet::Agent::Disabler do
  before(:all) do
    @lockdir = Dir.mktmpdir("disabler_spec_tmpdir")
    @lockfile = File.join(@lockdir, "lock")
  end

  after(:all) do
    FileUtils.rm_rf(@lockdir)
  end

  before(:each) do
    @locker = LockerTester.new
    @locker.stubs(:lockfile_path).returns @lockfile
  end

  it "should use an AnonymousFilelock instance as its disable_lockfile" do
    @locker.disable_lockfile.should be_instance_of(Puppet::Util::AnonymousFilelock)
  end

  it "should use 'lockfile_path' to determine its disable_lockfile path" do
    @locker.expects(:lockfile_path).returns @lockfile
    lock = Puppet::Util::AnonymousFilelock.new(@lockfile)
    Puppet::Util::AnonymousFilelock.expects(:new).with(@lockfile + ".disabled").returns lock

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

  describe "when enabling" do

    # this is for backwards compatibility with puppet versions prior to 2.7.10.
    # for more detailed information, see the comments in the "#check_for_old_lockfile" method,
    # in disabler.rb --cprice 2012-02-28
    describe "when a lockfile with the old filename already exists" do
      let(:warning_prefix) { "Found an agent lock file at path '#{@lockfile}'" }

      after(:each) do
        File.delete(@lockfile) if File.exists?(@lockfile)
      end

      describe "when the lockfile is empty" do
        before (:each) do
          FileUtils.touch(@lockfile)
        end

        it "should assume it was created by --disable in an old version of puppet, print a warning, and remove it" do
          Puppet.expects(:warning).with { |msg| msg =~ /^#{warning_prefix}.*Deleting the empty file/ }

          @locker.enable

          File.exists?(@lockfile).should == false
        end
      end

      describe "when the lockfile contains a pid" do
        before (:each) do
          File.open(@lockfile, "w") { |f| f.print(12345) }
        end

        it "should assume that there may be a running agent process, and print a warning" do
          Puppet.expects(:warning).with { |msg| msg =~ /^#{warning_prefix}.*appears that a puppet agent process is already running/ }

          @locker.enable

          File.exists?(@lockfile).should == true
        end
      end

      describe "when the lockfile contains something other than a pid" do
        before (:each) do
          File.open(@lockfile, "w") { |f| f.print("Foo\nbar\n\baz") }
        end

        it "should admit that it doesn't know what's going on, and print a warning" do
          Puppet.expects(:warning).with { |msg| msg =~ /^#{warning_prefix}.*unable to determine whether an existing agent is running or not/ }

          @locker.enable

          File.exists?(@lockfile).should == true
        end
      end
    end

  end
end
