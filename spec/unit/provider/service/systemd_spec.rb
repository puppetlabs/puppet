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
      Facter.stubs(:value).with(:osfamily).returns(osfamily)
      expect(described_class).to be_default
    end
  end

  it "should be the default provider on rhel7" do
    Facter.stubs(:value).with(:osfamily).returns(:redhat)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("7")
    expect(described_class).to be_default
  end

  [ 4, 5, 6 ].each do |ver|
    it "should not be the default provider on rhel#{ver}" do
      # In Ruby 1.8.7, the order of hash elements differs from 1.9+ and
      # caused short-circuiting of the logic used by default.all? in the
      # provider. As a workaround we need to use stubs() instead of
      # expects() here.
      Facter.stubs(:value).with(:osfamily).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
      expect(described_class).not_to be_default
    end
  end

  [ 17, 18, 19, 20, 21, 22, 23 ].each do |ver|
    it "should be the default provider on fedora#{ver}" do
      Facter.stubs(:value).with(:osfamily).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns(:fedora)
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
      expect(described_class).to be_default
    end
  end

  it "should be the default provider on sles12" do
    Facter.stubs(:value).with(:osfamily).returns(:suse)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("12")
    expect(described_class).to be_default
  end

  it "should be the default provider on opensuse13" do
    Facter.stubs(:value).with(:osfamily).returns(:suse)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("13")
    expect(described_class).to be_default
  end

  # tumbleweed is a rolling release with date-based major version numbers
  it "should be the default provider on tumbleweed" do
    Facter.stubs(:value).with(:osfamily).returns(:suse)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("20150829")
    expect(described_class).to be_default
  end

  # leap is the next generation suse release
  it "should be the default provider on leap" do
    Facter.stubs(:value).with(:osfamily).returns(:suse)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("42")
    expect(described_class).to be_default
  end

  it "should not be the default provider on debian7" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:debian)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("7")
    expect(described_class).not_to be_default
  end

  it "should be the default provider on debian8" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:debian)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("8")
    expect(described_class).to be_default
  end

  it "should not be the default provider on ubuntu14.04" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:ubuntu)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("14.04")
    expect(described_class).not_to be_default
  end

  it "should be the default provider on ubuntu15.04" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:ubuntu)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("15.04")
    expect(described_class).to be_default
  end

  it "should be the default provider on ubuntu15.10" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:ubuntu)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("15.10")
    expect(described_class).to be_default
  end

  it "should be the default provider on ubuntu16.04" do
    Facter.stubs(:value).with(:osfamily).returns(:debian)
    Facter.stubs(:value).with(:operatingsystem).returns(:ubuntu)
    Facter.stubs(:value).with(:operatingsystemmajrelease).returns("16.04")
    expect(described_class).to be_default
  end

  [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end
  end

  describe ".instances" do
    it "should have an instances method" do
      expect(described_class).to respond_to :instances
    end

    it "should return only services" do
      described_class.expects(:systemctl).with('list-unit-files', '--type', 'service', '--full', '--all', '--no-pager').returns File.read(my_fixture('list_unit_files_services'))
      expect(described_class.instances.map(&:name)).to match_array(%w{
        arp-ethers.service
        auditd.service
        autovt@.service
        avahi-daemon.service
        blk-availability.service
      })
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
      provider.expects(:systemctl).with(:unmask, 'sshd.service')
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
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "enabled\n"
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :true if the service is static" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "static\n"
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :false if the service is disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "disabled\n"
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :false if the service is masked and the resource is attempting to be disabled" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => false))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "masked\n"
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :mask if the service is masked and the resource is attempting to be masked" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => 'mask'))
      provider.expects(:execute).with(['/bin/systemctl','is-enabled','sshd.service'], :failonfail => false).returns "masked\n"
      expect(provider.enabled?).to eq(:mask)
    end
  end

  describe "#enable" do
    it "should run systemctl enable to enable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:systemctl).with(:unmask, 'sshd.service')
      provider.expects(:systemctl).with(:enable, 'sshd.service')
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

  describe "#mask" do
    it "should run systemctl to disable and mask a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      # :disable is the only call in the provider that uses a symbol instead of
      # a string.
      # This should be made consistent in the future and all tests updated.
      provider.expects(:systemctl).with(:disable, 'sshd.service')
      provider.expects(:systemctl).with(:mask, 'sshd.service')
      provider.mask
    end
  end

  # Note: systemd provider does not care about hasstatus or a custom status
  # command. I just assume that it does not make sense for systemd.
  describe "#status" do
    it "should return running if if the command returns 0" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      provider.expects(:execute).with(['/bin/systemctl','is-active','sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).returns "active\n"
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      expect(provider.status).to eq(:running)
    end

    [-10,-1,3,10].each { |ec|
      it "should return stopped if the command returns something non-0" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.expects(:execute).with(['/bin/systemctl','is-active','sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).returns "inactive\n"
        $CHILD_STATUS.stubs(:exitstatus).returns(ec)
        expect(provider.status).to eq(:stopped)
      end
    }

    it "should use the supplied status command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :status => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      provider.status
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

  describe "#debian_enabled?" do
    [104, 106].each do |status|
      it "should return true when invoke-rc.d returns #{status}" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        $CHILD_STATUS.expects(:exitstatus).returns(status)
        expect(provider.debian_enabled?).to eq(:true)
      end
    end

    [101, 105].each do |status|
      it "should return true when status is #{status} and there are at least 4 start links" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        provider.expects(:get_start_link_count).returns(4)
        $CHILD_STATUS.expects(:exitstatus).twice.returns(status)
        expect(provider.debian_enabled?).to eq(:true)
      end

      it "should return false when status is #{status} and there are less than 4 start links" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        provider.stubs(:system)
        provider.expects(:get_start_link_count).returns(1)
        $CHILD_STATUS.expects(:exitstatus).twice.returns(status)
        expect(provider.debian_enabled?).to eq(:false)
      end
    end
  end

  describe "#get_start_link_count" do
    it "should strip the '.service' from the search if present in the resource name" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      Dir.expects(:glob).with("/etc/rc*.d/S??sshd").returns(['files'])
      provider.get_start_link_count
    end

    it "should use the full service name if it does not include '.service'" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      Dir.expects(:glob).with("/etc/rc*.d/S??sshd").returns(['files'])
      provider.get_start_link_count
    end
  end

  it "(#16451) has command systemctl without being fully qualified" do
    expect(described_class.instance_variable_get(:@commands)).to include(:systemctl => 'systemctl')
  end
end
