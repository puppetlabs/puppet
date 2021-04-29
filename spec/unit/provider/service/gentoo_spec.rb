require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Gentoo',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:gentoo) }

  before(:all) do
    `exit 0`
  end

  before :each do
    allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class)
    allow(FileTest).to receive(:file?).with('/sbin/rc-update').and_return(true)
    allow(FileTest).to receive(:executable?).with('/sbin/rc-update').and_return(true)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return('Gentoo')
    allow(Facter).to receive(:value).with(:osfamily).and_return('Gentoo')

    # The initprovider (parent of the gentoo provider) does a stat call
    # before it even tries to execute an initscript. We use sshd in all the
    # tests so make sure it is considered present.
    sshd_path = '/etc/init.d/sshd'
    allow(Puppet::FileSystem).to receive(:stat).with(sshd_path).and_return(double('stat'))
  end

  let :initscripts do
    [
      'alsasound',
      'bootmisc',
      'functions.sh',
      'hwclock',
      'reboot.sh',
      'rsyncd',
      'shutdown.sh',
      'sshd',
      'vixie-cron',
      'wpa_supplicant',
      'xdm-setup'
    ]
  end

  let :helperscripts do
    [
      'functions.sh',
      'reboot.sh',
      'shutdown.sh'
    ]
  end

  let :process_output do
    Puppet::Util::Execution::ProcessOutput.new('', 0)
  end

  describe ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to(:instances)
    end

    it "should get a list of services from /etc/init.d but exclude helper scripts" do
      expect(FileTest).to receive(:directory?).with('/etc/init.d').and_return(true)
      expect(Dir).to receive(:entries).with('/etc/init.d').and_return(initscripts)
      (initscripts - helperscripts).each do |script|
        expect(FileTest).to receive(:executable?).with("/etc/init.d/#{script}").and_return(true)
      end
      helperscripts.each do |script|
        expect(FileTest).not_to receive(:executable?).with("/etc/init.d/#{script}")
      end

      allow(Puppet::FileSystem).to receive(:symlink?).and_return(false)
      expect(provider_class.instances.map(&:name)).to eq([
        'alsasound',
        'bootmisc',
        'hwclock',
        'rsyncd',
        'sshd',
        'vixie-cron',
        'wpa_supplicant',
        'xdm-setup'
      ])
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service with <initscript> start otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/etc/init.d/sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service with <initscript> stop otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/etc/init.d/sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
      provider.stop
    end
  end

  describe "#enabled?" do
    before :each do
      allow_any_instance_of(provider_class).to receive(:update).with(:show).and_return(File.read(my_fixture('rc_update_show')))
    end

    it "should run rc-update show to get a list of enabled services" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:update).with(:show).and_return("\n")
      provider.enabled?
    end

    ['hostname', 'net.lo', 'procfs'].each do |service|
      it "should consider service #{service} in runlevel boot as enabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['alsasound', 'xdm', 'netmount'].each do |service|
      it "should consider service #{service} in runlevel default as enabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['rsyncd', 'lighttpd', 'mysql'].each do |service|
      it "should consider unused service #{service} as disabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

  end

  describe "#enable" do
    it "should run rc-update add to enable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:update).with(:add, 'sshd', :default)
      provider.enable
    end
  end

  describe "#disable" do
    it "should run rc-update del to disable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:update).with(:del, 'sshd', :default)
      provider.disable
    end
  end

  describe "#status" do
    describe "when a special status command is specified" do
      it "should use the status command from the resource" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
          .and_return(process_output)
        provider.status
      end

      it "should return :stopped when the status command returns with a non-zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 3))
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when the status command returns with a zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
          .and_return(process_output)
        expect(provider.status).to eq(:running)
      end
    end

    describe "when hasstatus is false" do
      it "should return running if a pid can be found" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:getpid).and_return(1000)
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if no pid can be found" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:getpid).and_return(nil)
        expect(provider.status).to eq(:stopped)
      end
    end

    describe "when hasstatus is true" do
      it "should return running if <initscript> status exits with a zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
        expect(provider).to receive(:execute)
          .with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
          .and_return(process_output)
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if <initscript> status exits with a non-zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
        expect(provider).to receive(:execute)
          .with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 3))
        expect(provider.status).to eq(:stopped)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with <initscript> restart if hasrestart is true" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
      expect(provider).to receive(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with <initscript> stop/start if hasrestart is false" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      expect(provider).to receive(:search).with('sshd').and_return('/etc/init.d/sshd')
      expect(provider).not_to receive(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute).with(['/etc/init.d/sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute).with(['/etc/init.d/sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end
  end
end
