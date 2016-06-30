#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:service).provider(:gentoo) do

  if Puppet.features.microsoft_windows?
    # Get a pid for $CHILD_STATUS to latch on to
    command = "cmd.exe /c \"exit 0\""
    Puppet::Util::Execution.execute(command, {:failonfail => false})
  end

  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    FileTest.stubs(:file?).with('/sbin/rc-update').returns true
    FileTest.stubs(:executable?).with('/sbin/rc-update').returns true
    Facter.stubs(:value).with(:operatingsystem).returns 'Gentoo'
    Facter.stubs(:value).with(:osfamily).returns 'Gentoo'

    # The initprovider (parent of the gentoo provider) does a stat call
    # before it even tries to execute an initscript. We use sshd in all the
    # tests so make sure it is considered present.
    sshd_path = '/etc/init.d/sshd'
#    stub_file = stub(sshd_path, :stat => stub('stat'))
    Puppet::FileSystem.stubs(:stat).with(sshd_path).returns stub('stat')
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

  describe ".instances" do

    it "should have an instances method" do
      expect(described_class).to respond_to(:instances)
    end

    it "should get a list of services from /etc/init.d but exclude helper scripts" do
      FileTest.expects(:directory?).with('/etc/init.d').returns true
      Dir.expects(:entries).with('/etc/init.d').returns initscripts
      (initscripts - helperscripts).each do |script|
        FileTest.expects(:executable?).with("/etc/init.d/#{script}").returns true
      end
      helperscripts.each do |script|
        FileTest.expects(:executable?).with("/etc/init.d/#{script}").never
      end

      Puppet::FileSystem.stubs(:symlink?).returns false # stub('file', :symlink? => false)
      expect(described_class.instances.map(&:name)).to eq([
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
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end
    it "should start the service with <initscript> start otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/init.d/sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end
    it "should stop the service with <initscript> stop otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/init.d/sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
      provider.stop
    end
  end

  describe "#enabled?" do

    before :each do
      described_class.any_instance.stubs(:update).with(:show).returns File.read(my_fixture('rc_update_show'))
    end

    it "should run rc-update show to get a list of enabled services" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:update).with(:show).returns "\n"
      provider.enabled?
    end

    ['hostname', 'net.lo', 'procfs'].each do |service|
      it "should consider service #{service} in runlevel boot as enabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['alsasound', 'xdm', 'netmount'].each do |service|
      it "should consider service #{service} in runlevel default as enabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['rsyncd', 'lighttpd', 'mysql'].each do |service|
      it "should consider unused service #{service} as disabled" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

  end

  describe "#enable" do
    it "should run rc-update add to enable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:update).with(:add, 'sshd', :default)
      provider.enable
    end
  end

  describe "#disable" do
    it "should run rc-update del to disable a service" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:update).with(:del, 'sshd', :default)
      provider.disable
    end
  end

  describe "#status" do

    describe "when a special status command is specified" do
      it "should use the status command from the resource" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        provider.status
      end

      it "should return :stopped when the status command returns with a non-zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 3
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when the status command returns with a zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end
    end

    describe "when hasstatus is false" do
      it "should return running if a pid can be found" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:getpid).returns 1000
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if no pid can be found" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
        provider.expects(:getpid).returns nil
        expect(provider.status).to eq(:stopped)
      end
    end

    describe "when hasstatus is true" do
      it "should return running if <initscript> status exits with a zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 0
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if <initscript> status exits with a non-zero exitcode" do
        provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
        provider.expects(:execute).with(['/etc/init.d/sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        $CHILD_STATUS.stubs(:exitstatus).returns 3
        expect(provider.status).to eq(:stopped)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with <initscript> restart if hasrestart is true" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
      provider.expects(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with <initscript> stop/start if hasrestart is false" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      provider.expects(:search).with('sshd').returns('/etc/init.d/sshd')
      provider.expects(:execute).with(['/etc/init.d/sshd',:restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/etc/init.d/sshd',:stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:execute).with(['/etc/init.d/sshd',:start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end
  end

end
