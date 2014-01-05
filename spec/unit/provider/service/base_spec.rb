#! /usr/bin/env ruby
require 'spec_helper'
require 'rbconfig'
require 'fileutils'

provider_class = Puppet::Type.type(:service).provider(:init)

describe "base service provider" do
  include PuppetSpec::Files

  let :type do Puppet::Type.type(:service) end
  let :provider do type.provider(:base) end

  subject { provider }

  context "basic operations" do
    # Cross-platform file interactions.  Fun times.
    Ruby = File.join(RbConfig::CONFIG["bindir"],
                     RbConfig::CONFIG["RUBY_INSTALL_NAME"] +
                     RbConfig::CONFIG["EXEEXT"])

    Start  = [Ruby, '-rfileutils', '-e', 'FileUtils.touch(ARGV[0])']
    Status = [Ruby, '-e' 'exit File.file?(ARGV[0])']
    Stop   = [Ruby, '-e', 'File.exist?(ARGV[0]) and File.unlink(ARGV[0])']

    let :flag do tmpfile('base-service-test') end

    subject do
      type.new(:name  => "test", :provider => :base,
               :start  => Start  + [flag],
               :status => Status + [flag],
               :stop   => Stop   + [flag]
      ).provider
    end

    before :each do
      Puppet::FileSystem.unlink(flag) if Puppet::FileSystem.exist?(flag)
    end

    it { should be }

    it "should invoke the start command if not running" do
      File.should_not be_file(flag)
      subject.start
      File.should be_file(flag)
    end

    it "should be stopped before being started" do
      subject.status.should == :stopped
    end

    it "should be running after being started" do
      subject.start
      subject.status.should == :running
    end

    it "should invoke the stop command when asked" do
      subject.start
      subject.status.should == :running
      subject.stop
      subject.status.should == :stopped
      File.should_not be_file(flag)
    end

    it "should start again even if already running" do
      subject.start
      subject.expects(:ucommand).with(:start)
      subject.start
    end

    it "should stop again even if already stopped" do
      subject.stop
      subject.expects(:ucommand).with(:stop)
      subject.stop
    end
  end
end
