#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:openrc) do

  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    ['/sbin/rc-service', '/bin/rc-status', '/sbin/rc-update'].each do |command|
      # Puppet::Util is both mixed in to providers and is also invoked directly
      # by Puppet::Provider::CommandDefiner, so we have to stub both out.
      described_class.stubs(:which).with(command).returns(command)
      Puppet::Util.stubs(:which).with(command).returns(command)
    end
  end

  describe ".instances" do

    it "should have an instances method" do
      expect(described_class).to respond_to :instances
    end

    it "should get a list of services from rc-service --list" do
      described_class.expects(:rcservice).with('-C','--list').returns File.read(my_fixture('rcservice_list'))
      expect(described_class.instances.map(&:name)).to eq([
        'alsasound',
        'consolefont',
        'lvm-monitoring',
        'pydoc-2.7',
        'pydoc-3.2',
        'wpa_supplicant',
        'xdm',
        'xdm-setup'
      ])
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end
    it "should start the service with rc-service start otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end
    it "should stop the service with rc-service stop otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end
  end

  describe 'when invoking `rc-status`' do
    subject { described_class.new(Puppet::Type.type(:service).new(:name => 'urandom')) }
    it "clears the RC_SVCNAME environment variable" do
      Puppet::Util.withenv(:RC_SVCNAME => 'puppet') do
        Puppet::Util::Execution.expects(:execute).with(
          includes('/bin/rc-status'),
          has_entry(:custom_environment, {:RC_SVCNAME => nil})
        ).returns ''
        subject.enabled?
      end
    end
  end

  describe "#enabled?" do

    before :each do
      described_class.any_instance.stubs(:rcstatus).with('-C','-a').returns File.read(my_fixture('rcstatus'))
    end

    it "should run rc-status to get a list of enabled services" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:rcstatus).with('-C','-a').returns "\n"
      provider.enabled?
    end

    ['hwclock', 'modules', 'urandom'].each do |service|
      it "should consider service #{service} in runlevel boot as enabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['netmount', 'xdm', 'local', 'foo_with_very_very_long_servicename_no_still_not_the_end_wait_for_it_almost_there_almost_there_now_finally_the_end'].each do |service|
      it "should consider service #{service} in runlevel default as enabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['net.eth0', 'pcscd'].each do |service|
      it "should consider service #{service} in dynamic runlevel: hotplugged as disabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

    ['sysfs', 'udev-mount'].each do |service|
      it "should consider service #{service} in dynamic runlevel: needed as disabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

    ['sshd'].each do |service|
      it "should consider service #{service} in dynamic runlevel: manual as disabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

  end

  describe "#enable" do
    it "should run rc-update add to enable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:rcupdate).with('-C', :add, 'sshd')
      provider.enable
    end
  end

  describe "#disable" do
    it "should run rc-update del to disable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:rcupdate).with('-C', :del, 'sshd')
      provider.disable
    end
  end

  describe "#status" do

    describe "when a special status command if specified" do
      it "should use the status command from the resource" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.status
      end

      it "should return :stopped when status command returns with a non-zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 3
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when status command returns with a zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end
    end

    describe "when hasstatus is false" do
      it "should return running if a pid can be found" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:getpid).returns 1000
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if no pid can be found" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:getpid).returns nil
        expect(provider.status).to eq(:stopped)
      end
    end

    describe "when hasstatus is true" do
      it "should return running if rc-service status exits with a zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if rc-service status exits with a non-zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        provider.expects(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 3
        expect(provider.status).to eq(:stopped)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with rc-service restart if hasrestart is true" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with rc-service stop/start if hasrestart is false" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:execute).with(['/sbin/rc-service','sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end
  end

end
