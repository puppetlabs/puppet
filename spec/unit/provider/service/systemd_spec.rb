#! /usr/bin/env ruby
#
# Unit testing for the systemd service Provider
#
require 'spec_helper'

describe Puppet::Type.type(:service).provider(:systemd) do
  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    described_class.stubs(:which).with('systemctl').returns '/bin/systemctl'
  end


  let :provider do
    described_class.new(:name => 'sshd.service')
  end

  osfamily = [ 'archlinux' ]

  osfamily.each do |osfamily|
    it "should be the default provider on #{osfamily}" do
      Facter.expects(:value).with(:osfamily).returns(osfamily)
      described_class.default?.should be_true
    end
  end

  it "should be the default provider on rhel7" do
    Facter.expects(:value).with(:osfamily).at_least_once.returns(:redhat)
    Facter.expects(:value).with(:operatingsystemmajrelease).returns("7")
    described_class.default?.should be_true
  end

  [ 4, 5, 6 ].each do |ver|
    it "should not be the default provider on rhel#{ver}" do
      # In Ruby 1.8.7, the order of hash elements differs from 1.9+ and
      # caused short-circuiting of the logic used by default.all? in the
      # provider. As a workaround we need to use stubs() instead of
      # expects() here. 
      Facter.expects(:value).with(:osfamily).at_least_once.returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
      described_class.default?.should_not be_true
    end
  end

  [ 17, 18, 19, 20, 21 ].each do |ver|
    it "should be the default provider on fedora#{ver}" do
      Facter.expects(:value).with(:osfamily).at_least_once.returns(:redhat)
      Facter.expects(:value).with(:operatingsystem).at_least_once.returns(:fedora)
      Facter.expects(:value).with(:operatingsystemmajrelease).at_least_once.returns("#{ver}")
      described_class.default?.should be_true
    end
  end

  [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      provider.should respond_to(method)
    end
  end

  describe ".instances" do
    it "should have an instances method" do
      described_class.should respond_to :instances
    end

    it "should return only services" do
      described_class.expects(:systemctl).with('list-unit-files', '--type', 'service', '--full', '--all', '--no-pager').returns File.read(my_fixture('list_unit_files_services'))
      described_class.instances.map(&:name).should =~ %w{
        arp-ethers.service
        auditd.service
        autovt@.service
        avahi-daemon.service
        blk-availability.service
      }
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service with systemctl start otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','start','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service with systemctl stop otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','stop','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end
  end

  describe "#enabled?" do
    it "should return :true if the service is enabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with('is-enabled', 'sshd.service').returns 'enabled'
      provider.enabled?.should == :true
    end

    it "should return :false if the service is disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with('is-enabled', 'sshd.service').raises Puppet::ExecutionFailure, "Execution of '/bin/systemctl is-enabled sshd.service' returned 1: disabled"
      provider.enabled?.should == :false
    end
  end

  describe "#enable" do
    it "should run systemctl enable to enable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with('enable', 'sshd.service')
      provider.enable
    end
  end

  describe "#disable" do
    it "should run systemctl disable to disable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:disable, 'sshd.service')
      provider.disable
    end
  end

  # Note: systemd provider does not care about hasstatus or a custom status
  # command. I just assume that it does not make sense for systemd.
  describe "#status" do
    it "should return running if active" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with('is-active', 'sshd.service').returns 'active'
      provider.status.should == :running
    end

    it "should return stopped if inactive" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with('is-active', 'sshd.service').raises Puppet::ExecutionFailure, "Execution of '/bin/systemctl is-active sshd.service' returned 3: inactive"
      provider.status.should == :stopped
    end
  end

  # Note: systemd provider does not care about hasrestart. I just assume it
  # does not make sense for systemd
  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/bin/systemctl','restart','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with systemctl restart" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','restart','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end
  end

  it "(#16451) has command systemctl without being fully qualified" do
    described_class.instance_variable_get(:@commands).
      should include(:systemctl => 'systemctl')
  end

end
