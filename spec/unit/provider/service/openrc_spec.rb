require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Openrc',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:openrc) }

  before :each do
    allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class)
    ['/sbin/rc-service', '/bin/rc-status', '/sbin/rc-update'].each do |command|
      # Puppet::Util is both mixed in to providers and is also invoked directly
      # by Puppet::Provider::CommandDefiner, so we have to stub both out.
      allow(provider_class).to receive(:which).with(command).and_return(command)
      allow(Puppet::Util).to receive(:which).with(command).and_return(command)
    end
  end

  describe ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should get a list of services from rc-service --list" do
      expect(provider_class).to receive(:rcservice).with('-C','--list').and_return(File.read(my_fixture('rcservice_list')))
      expect(provider_class.instances.map(&:name)).to eq([
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
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.start
    end

    it "should start the service with rc-service start otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/sbin/rc-service','sshd',:start], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.stop
    end

    it "should stop the service with rc-service stop otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/sbin/rc-service','sshd',:stop], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.stop
    end
  end

  describe 'when invoking `rc-status`' do
    subject { provider_class.new(Puppet::Type.type(:service).new(:name => 'urandom')) }

    it "clears the RC_SVCNAME environment variable" do
      Puppet::Util.withenv(:RC_SVCNAME => 'puppet') do
        expect(Puppet::Util::Execution).to receive(:execute).with(
          include('/bin/rc-status'),
          hash_including(custom_environment:  hash_including(RC_SVCNAME: nil))
        ).and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))

        subject.enabled?
      end
    end
  end

  describe "#enabled?" do
    before :each do
      allow_any_instance_of(provider_class).to receive(:rcstatus).with('-C','-a').and_return(File.read(my_fixture('rcstatus')))
    end

    it "should run rc-status to get a list of enabled services" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:rcstatus).with('-C','-a').and_return("\n")
      provider.enabled?
    end

    ['hwclock', 'modules', 'urandom'].each do |service|
      it "should consider service #{service} in runlevel boot as enabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['netmount', 'xdm', 'local', 'foo_with_very_very_long_servicename_no_still_not_the_end_wait_for_it_almost_there_almost_there_now_finally_the_end'].each do |service|
      it "should consider service #{service} in runlevel default as enabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:true)
      end
    end

    ['net.eth0', 'pcscd'].each do |service|
      it "should consider service #{service} in dynamic runlevel: hotplugged as disabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

    ['sysfs', 'udev-mount'].each do |service|
      it "should consider service #{service} in dynamic runlevel: needed as disabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

    ['sshd'].each do |service|
      it "should consider service #{service} in dynamic runlevel: manual as disabled" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => service))
        expect(provider.enabled?).to eq(:false)
      end
    end

  end

  describe "#enable" do
    it "should run rc-update add to enable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:rcupdate).with('-C', :add, 'sshd')
      provider.enable
    end
  end

  describe "#disable" do
    it "should run rc-update del to disable a service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:rcupdate).with('-C', :del, 'sshd')
      provider.disable
    end
  end

  describe "#status" do
    describe "when a special status command if specified" do
      it "should use the status command from the resource" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        provider.status
      end

      it "should return :stopped when status command returns with a non-zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 3))
        expect(provider.status).to eq(:stopped)
      end

      it "should return :running when status command returns with a zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
        expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
        expect(provider).to receive(:execute)
          .with(['/bin/foo'], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        expect(provider.status).to eq(:running)
      end
    end

    describe "when hasstatus is false" do
      it "should return running if a pid can be found" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
        expect(provider).to receive(:getpid).and_return(1000)
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if no pid can be found" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => false))
        expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
        expect(provider).to receive(:getpid).and_return(nil)
        expect(provider.status).to eq(:stopped)
      end
    end

    describe "when hasstatus is true" do
      it "should return running if rc-service status exits with a zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        expect(provider).to receive(:execute)
          .with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        expect(provider.status).to eq(:running)
      end

      it "should return stopped if rc-service status exits with a non-zero exitcode" do
        provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasstatus => true))
        expect(provider).to receive(:execute)
          .with(['/sbin/rc-service','sshd',:status], {:failonfail => false, :override_locale => false, :squelch => false, :combine => true})
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 3))
        expect(provider.status).to eq(:stopped)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:restart], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      expect(provider).to receive(:execute).with(['/bin/foo'], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.restart
    end

    it "should restart the service with rc-service restart if hasrestart is true" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      expect(provider).to receive(:execute).with(['/sbin/rc-service','sshd',:restart], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.restart
    end

    it "should restart the service with rc-service stop/start if hasrestart is false" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      expect(provider).not_to receive(:execute).with(['/sbin/rc-service','sshd',:restart], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      expect(provider).to receive(:execute).with(['/sbin/rc-service','sshd',:stop], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      expect(provider).to receive(:execute).with(['/sbin/rc-service','sshd',:start], {:failonfail => true, :override_locale => false, :squelch => false, :combine => true})
      provider.restart
    end
  end
end
