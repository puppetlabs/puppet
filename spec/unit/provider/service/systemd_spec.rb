require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Systemd',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do

  let(:provider_class) { Puppet::Type.type(:service).provider(:systemd) }

  before :each do
    allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class)
    allow(provider_class).to receive(:which).with('systemctl').and_return('/bin/systemctl')
  end

  # `execute` and `texecute` start a new process, consequently setting $CHILD_STATUS to a Process::Status instance,
  # but because they are mocked, an external process is never executed and $CHILD_STATUS remain nil.
  # In order to execute some parts of the code under test and to mock $CHILD_STATUS, we need this variable to be a
  # Process::Status instance. We can achieve this by starting a process that does nothing (exit 0). By doing this,
  # $CHILD_STATUS will be initialised with a instance of Process::Status and we will be able to mock it.
  before(:all) do
    `exit 0`
  end

  let :provider do
    provider_class.new(:name => 'sshd.service')
  end

  osfamilies = [ 'archlinux', 'coreos' ]

  osfamilies.each do |osfamily|
    it "should be the default provider on #{osfamily}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(osfamily)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(osfamily)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("1234")
      expect(provider_class).to be_default
    end
  end

  [7, 8].each do |ver|
    it "should be the default provider on rhel#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:redhat)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return(ver.to_s)
      expect(provider_class).to be_default
    end
  end

  [ 4, 5, 6 ].each do |ver|
    it "should not be the default provider on rhel#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:redhat)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
      expect(provider_class).not_to be_default
    end
  end

  [ 17, 18, 19, 20, 21, 22, 23 ].each do |ver|
    it "should be the default provider on fedora#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:fedora)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
      expect(provider_class).to be_default
    end
  end

  it "should be the default provider on Amazon Linux 2.0" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:amazon)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("2")
    expect(provider_class).to be_default
  end

  it "should not be the default provider on Amazon Linux 2017.09" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:redhat)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:amazon)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("2017")
    expect(provider_class).not_to be_default
  end

  it "should be the default provider on cumulus3" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return('CumulusLinux')
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("3")
    expect(provider_class).to be_default
  end

  it "should be the default provider on sles12" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("12")
    expect(provider_class).to be_default
  end

  it "should be the default provider on opensuse13" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("13")
    expect(provider_class).to be_default
  end

  # tumbleweed is a rolling release with date-based major version numbers
  it "should be the default provider on tumbleweed" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("20150829")
    expect(provider_class).to be_default
  end

  # leap is the next generation suse release
  it "should be the default provider on leap" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:leap)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("42")
    expect(provider_class).to be_default
  end

  it "should not be the default provider on debian7" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("7")
    expect(provider_class).not_to be_default
  end

  it "should be the default provider on debian8" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("8")
    expect(provider_class).to be_default
  end

  it "should be the default provider on debian11" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("11")
    expect(provider_class).to be_default
  end

  it "should be the default provider on debian bookworm/sid" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("bookworm/sid")
    expect(provider_class).to be_default
  end

  it "should not be the default provider on ubuntu14.04" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:ubuntu)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("14.04")
    expect(provider_class).not_to be_default
  end

  [ '15.04', '15.10', '16.04', '16.10', '17.04', '17.10', '18.04' ].each do |ver|
    it "should be the default provider on ubuntu#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:ubuntu)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
      expect(provider_class).to be_default
    end
  end

  [ '10', '11', '12', '13', '14', '15', '16', '17' ].each do |ver|
    it "should not be the default provider on LinuxMint#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:LinuxMint)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
      expect(provider_class).not_to be_default
    end
  end

  [ '18', '19' ].each do |ver|
    it "should be the default provider on LinuxMint#{ver}" do
      allow(Facter).to receive(:value).with(:osfamily).and_return(:debian)
      allow(Facter).to receive(:value).with(:operatingsystem).and_return(:LinuxMint)
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("#{ver}")
      expect(provider_class).to be_default
    end
  end

  [:enabled?, :daemon_reload?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end
  end

  describe ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should return only services" do
      expect(provider_class).to receive(:systemctl).with('list-unit-files', '--type', 'service', '--full', '--all', '--no-pager').and_return(File.read(my_fixture('list_unit_files_services')))
      expect(provider_class.instances.map(&:name)).to match_array(%w{
        arp-ethers.service
        auditd.service
        autovt@.service
        avahi-daemon.service
        blk-availability.service
        apparmor.service
        umountnfs.service
        urandom.service
        brandbot.service
      })
    end

    it "should print a debug message when a service with the state `bad` is found" do
      expect(provider_class).to receive(:systemctl).with('list-unit-files', '--type', 'service', '--full', '--all', '--no-pager').and_return(File.read(my_fixture('list_unit_files_services')))
      expect(Puppet).to receive(:debug).with("apparmor.service marked as bad by `systemctl`. It is recommended to be further checked.")
      provider_class.instances
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :start => '/bin/foo'))
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service with systemctl start otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:systemctl).with(:unmask, '--', 'sshd.service')
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/systemctl','start', '--', 'sshd.service'], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.start
    end

    it "should show journald logs on failure" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:systemctl).with(:unmask, '--', 'sshd.service')
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/systemctl','start', '--', 'sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .and_raise(Puppet::ExecutionFailure, "Failed to start sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      expect(provider).to receive(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").and_return(journalctl_logs)
      expect { provider.start }.to raise_error(Puppet::Error, /Systemd start for sshd.service failed![\n]+journalctl log for sshd.service:[\n]+-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/m)
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :stop => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service with systemctl stop otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','stop', '--', 'sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should show journald logs on failure" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','stop', '--', 'sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .and_raise(Puppet::ExecutionFailure, "Failed to stop sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      expect(provider).to receive(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").and_return(journalctl_logs)
      expect { provider.stop }.to raise_error(Puppet::Error, /Systemd stop for sshd.service failed![\n]+journalctl log for sshd.service:[\n]-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/m)
    end
  end

  describe "#daemon_reload?" do
    it "should skip the systemctl daemon_reload if not required by the service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl', 'show', '--property=NeedDaemonReload', '--', 'sshd.service'], :failonfail => false).and_return("no")
      provider.daemon_reload?
    end
    it "should run a systemctl daemon_reload if the service has been modified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl', 'show', '--property=NeedDaemonReload', '--', 'sshd.service'], :failonfail => false).and_return("yes")
      expect(provider).to receive(:execute).with(['/bin/systemctl', 'daemon-reload'], :failonfail => false)
      provider.daemon_reload?
    end
  end

  describe "#enabled?" do
    it "should return :true if the service is enabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled', '--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("enabled\n", 0))
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :true if the service is static" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled','--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("static\n", 0))
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :false if the service is disabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled', '--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("disabled\n", 1))
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :false if the service is indirect" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled', '--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("indirect\n", 0))
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :false if the service is masked and the resource is attempting to be disabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => false))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled', '--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("masked\n", 1))
      expect(provider.enabled?).to eq(:false)
    end

    it "should return :mask if the service is masked and the resource is attempting to be masked" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => 'mask'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-enabled', '--', 'sshd.service'], :failonfail => false).
                            and_return(Puppet::Util::Execution::ProcessOutput.new("masked\n", 1))
      expect(provider.enabled?).to eq(:mask)
    end
  end

  describe "#enable" do
    it "should run systemctl enable to enable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:systemctl).with(:unmask, '--', 'sshd.service')
      expect(provider).to receive(:systemctl).with(:enable, '--', 'sshd.service')
      provider.enable
    end
  end

  describe "#disable" do
    it "should run systemctl disable to disable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:systemctl).with(:disable, '--', 'sshd.service')
      provider.disable
    end
  end

  describe "#mask" do
    it "should run systemctl to disable and mask a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      # :disable is the only call in the provider that uses a symbol instead of
      # a string.
      # This should be made consistent in the future and all tests updated.
      expect(provider).to receive(:systemctl).with(:disable, '--', 'sshd.service')
      expect(provider).to receive(:systemctl).with(:mask, '--', 'sshd.service')
      provider.mask
    end
  end

  # Note: systemd provider does not care about hasstatus or a custom status
  # command. I just assume that it does not make sense for systemd.
  describe "#status" do
    it "should return running if if the command returns 0" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:execute).with(['/bin/systemctl','is-active', '--', 'sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).and_return("active\n")
      allow($CHILD_STATUS).to receive(:exitstatus).and_return(0)
      expect(provider.status).to eq(:running)
    end

    [-10,-1,3,10].each { |ec|
      it "should return stopped if the command returns something non-0" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        expect(provider).to receive(:execute).with(['/bin/systemctl','is-active', '--', 'sshd.service'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).and_return("inactive\n")
        allow($CHILD_STATUS).to receive(:exitstatus).and_return(ec)
        expect(provider.status).to eq(:stopped)
      end
    }

    it "should use the supplied status command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :status => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      provider.status
    end
  end

  # Note: systemd provider does not care about hasrestart. I just assume it
  # does not make sense for systemd
  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/systemctl','restart', '--', 'sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with systemctl restart" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/systemctl','restart','--','sshd.service'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should show journald logs on failure" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(provider).to receive(:daemon_reload?).and_return('no')
      expect(provider).to receive(:execute).with(['/bin/systemctl','restart','--','sshd.service'],{:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
        .and_raise(Puppet::ExecutionFailure, "Failed to restart sshd.service: Unit sshd.service failed to load: Invalid argument. See system logs and 'systemctl status sshd.service' for details.")
      journalctl_logs = <<-EOS
-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --
Jun 14 21:41:34 foo.example.com systemd[1]: Stopping sshd Service...
Jun 14 21:41:35 foo.example.com systemd[1]: Starting sshd Service...
Jun 14 21:43:23 foo.example.com systemd[1]: sshd.service lacks both ExecStart= and ExecStop= setting. Refusing.
      EOS
      expect(provider).to receive(:execute).with("journalctl -n 50 --since '5 minutes ago' -u sshd.service --no-pager").and_return(journalctl_logs)
      expect { provider.restart }.to raise_error(Puppet::Error, /Systemd restart for sshd.service failed![\n]+journalctl log for sshd.service:[\n]+-- Logs begin at Tue 2016-06-14 11:59:21 UTC, end at Tue 2016-06-14 21:45:02 UTC. --/m)
    end
  end

  describe "#debian_enabled?" do
    [104, 106].each do |status|
      it "should return true when invoke-rc.d returns #{status}" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        allow(provider).to receive(:system)
        expect($CHILD_STATUS).to receive(:exitstatus).and_return(status)
        expect(provider.debian_enabled?).to eq(:true)
      end
    end

    [101, 105].each do |status|
      it "should return true when status is #{status} and there are at least 4 start links" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        allow(provider).to receive(:system)
        expect(provider).to receive(:get_start_link_count).and_return(4)
        expect($CHILD_STATUS).to receive(:exitstatus).twice.and_return(status)
        expect(provider.debian_enabled?).to eq(:true)
      end

      it "should return false when status is #{status} and there are less than 4 start links" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
        allow(provider).to receive(:system)
        expect(provider).to receive(:get_start_link_count).and_return(1)
        expect($CHILD_STATUS).to receive(:exitstatus).twice.and_return(status)
        expect(provider.debian_enabled?).to eq(:false)
      end
    end
  end

  describe "#insync_enabled?" do
    let(:provider) do
      provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service', :enable => false))
    end

    before do
      allow(provider).to receive(:cached_enabled?).and_return({ output: service_state, exitcode: 0 })
    end

    context 'when service state is static' do
      let(:service_state) { 'static' }

      it 'is always enabled_insync even if current value is the same as expected' do
        expect(provider).to be_enabled_insync(:false)
      end

      it 'is always enabled_insync even if current value is not the same as expected' do
        expect(provider).to be_enabled_insync(:true)
      end

      it 'logs a debug messsage' do
        expect(Puppet).to receive(:debug).with("Unable to enable or disable static service sshd.service")
        provider.enabled_insync?(:true)
      end
    end

    context 'when service state is indirect' do
      let(:service_state) { 'indirect' }

      it 'is always enabled_insync even if current value is the same as expected' do
        expect(provider).to be_enabled_insync(:false)
      end

      it 'is always enabled_insync even if current value is not the same as expected' do
        expect(provider).to be_enabled_insync(:true)
      end

      it 'logs a debug messsage' do
        expect(Puppet).to receive(:debug).with("Service sshd.service is in 'indirect' state and cannot be enabled/disabled")
        provider.enabled_insync?(:true)
      end
    end

    context 'when service state is enabled' do
      let(:service_state) { 'enabled' }

      it 'is enabled_insync if current value is the same as expected' do
        expect(provider).to be_enabled_insync(:false)
      end

      it 'is not enabled_insync if current value is not the same as expected' do
        expect(provider).not_to be_enabled_insync(:true)
      end

      it 'logs no debug messsage' do
        expect(Puppet).not_to receive(:debug)
        provider.enabled_insync?(:true)
      end
    end
  end

  describe "#get_start_link_count" do
    it "should strip the '.service' from the search if present in the resource name" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd.service'))
      expect(Dir).to receive(:glob).with("/etc/rc*.d/S??sshd").and_return(['files'])
      provider.get_start_link_count
    end

    it "should use the full service name if it does not include '.service'" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(Dir).to receive(:glob).with("/etc/rc*.d/S??sshd").and_return(['files'])
      provider.get_start_link_count
    end
  end

  it "(#16451) has command systemctl without being fully qualified" do
    expect(provider_class.instance_variable_get(:@commands)).to include(:systemctl => 'systemctl')
  end
end
