#!/usr/bin/env ruby
#
# Unit testing for the OpenBSD service provider

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:openbsd)

describe provider_class do
  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    Facter.stubs(:value).with(:operatingsystem).returns :openbsd
  end

  let :rcscripts do
    [
     'apmd',
     'aucat',
     'cron',
     'puppetd'
   ]
  end

  describe "#instances" do
    it "should have an instances method" do
      described_class.should respond_to :instances
    end

    it "should list all available services" do
      FileTest.expects(:directory?).with('/etc/rc.d').returns true
      Dir.expects(:entries).with('/etc/rc.d').returns rcscripts

      rcscripts.each do |script|
        FileTest.expects(:executable?).with("/etc/rc.d/#{script}").returns true
      end

      described_class.instances.map(&:name).should == [
        'apmd',
        'aucat',
        'cron',
        'puppetd'
      ]
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => true)
      provider.start
    end

    it "should start the service otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :start], :failonfail => true, :override_locale => false, :squelch => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => true)
      provider.stop
    end

    it "should stop the service otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :stop], :failonfail => true, :override_locale => false, :squelch => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.stop
    end
  end

  describe "#status" do
    it "should use the status command from the resource" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => true)
      provider.status
    end

      it "should return :stopped when status command returns with a non-zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 3
        provider.status.should == :stopped
      end

      it "should return :running when status command returns with a zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.status.should == :running
      end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => true)
      provider.restart
    end

    it "should restart the service with rc-service restart if hasrestart is true" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.restart
    end

    it "should restart the service with rc-service stop/start if hasrestart is false" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => true).never
      provider.expects(:execute).with(['/etc/rc.d/sshd', :stop], :failonfail => true, :override_locale => false, :squelch => true)
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :start], :failonfail => true, :override_locale => false, :squelch => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.restart
    end
  end
end
