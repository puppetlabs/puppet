require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Openbsd',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:openbsd) }

  before :each do
    allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:openbsd)
    allow(Facter).to receive(:value).with(:osfamily).and_return('OpenBSD')
    allow(FileTest).to receive(:file?).with('/usr/sbin/rcctl').and_return(true)
    allow(FileTest).to receive(:executable?).with('/usr/sbin/rcctl').and_return(true)
  end

  # `execute` and `texecute` start a new process, consequently setting $CHILD_STATUS to a Process::Status instance,
  # but because they are mocked, an external process is never executed and $CHILD_STATUS remain nil.
  # In order to execute some parts of the code under test and to mock $CHILD_STATUS, we need this variable to be a
  # Process::Status instance. We can achieve this by starting a process that does nothing (exit 0). By doing this,
  # $CHILD_STATUS will be initialised with a instance of Process::Status and we will be able to mock it.
  before(:all) do
    `exit 0`
  end

  context "#instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should list all available services" do
      allow(provider_class).to receive(:execpipe).with(['/usr/sbin/rcctl', :getall]).and_yield(File.read(my_fixture('rcctl_getall')))
      expect(provider_class.instances.map(&:name)).to eq([
        'accounting', 'pf', 'postgresql', 'tftpd', 'wsmoused', 'xdm',
      ])
    end
  end

  context "#start" do
    it "should use the supplied start command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', '-f', :start, 'sshd'], hash_including(failonfail: true))
      provider.start
    end
  end

  context "#stop" do
    it "should use the supplied stop command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      expect(provider).to receive(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service otherwise" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', :stop, 'sshd'], hash_including(failonfail: true))
      provider.stop
    end
  end

  context "#status" do
    it "should use the status command from the resource" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/usr/sbin/rcctl', :get, 'sshd', :status], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute)
       .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
       .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      provider.status
    end

    it "should return :stopped when status command returns with a non-zero exitcode" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/usr/sbin/rcctl', :get, 'sshd', :status], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute)
        .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 3))
      expect(provider.status).to eq(:stopped)
    end

    it "should return :running when status command returns with a zero exitcode" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/usr/sbin/rcctl', :get, 'sshd', :status], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute)
        .with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      expect(provider.status).to eq(:running)
    end
  end

  context "#restart" do
    it "should use the supplied restart command if specified" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      expect(provider).not_to receive(:execute).with(['/usr/sbin/rcctl', '-f', :restart, 'sshd'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      expect(provider).to receive(:execute)
        .with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      provider.restart
    end

    it "should restart the service with rcctl restart if hasrestart is true" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', '-f', :restart, 'sshd'], hash_including(failonfail: true))
      provider.restart
    end

    it "should restart the service with rcctl stop/start if hasrestart is false" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      expect(provider).not_to receive(:execute).with(['/usr/sbin/rcctl', '-f', :restart, 'sshd'], any_args)
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', :stop, 'sshd'], hash_including(failonfail: true))
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', '-f', :start, 'sshd'], hash_including(failonfail: true))
      provider.restart
    end
  end

  context "#enabled?" do
    it "should return :true if the service is enabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:get, 'sshd', :status)
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'get', 'sshd', 'status'], :failonfail => false, :combine => false, :squelch => false).and_return(double(:exitstatus => 0))
      expect(provider.enabled?).to eq(:true)
    end

    it "should return :false if the service is disabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:get, 'sshd', :status).and_return('NO')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'get', 'sshd', 'status'], :failonfail => false, :combine => false, :squelch => false).and_return(double(:exitstatus => 1))
      expect(provider.enabled?).to eq(:false)
    end
  end

  context "#enable" do
    it "should run rcctl enable to enable the service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:enable, 'sshd').and_return('')
      expect(provider).to receive(:rcctl).with(:enable, 'sshd')
      provider.enable
    end

    it "should run rcctl enable with flags if provided" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :flags => '-6'))
      allow(provider_class).to receive(:rcctl).with(:enable, 'sshd').and_return('')
      allow(provider_class).to receive(:rcctl).with(:set, 'sshd', :flags, '-6').and_return('')
      expect(provider).to receive(:rcctl).with(:enable, 'sshd')
      expect(provider).to receive(:rcctl).with(:set, 'sshd', :flags, '-6')
      provider.enable
    end
  end

  context "#disable" do
    it "should run rcctl disable to disable the service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:disable, 'sshd').and_return('')
      expect(provider).to receive(:rcctl).with(:disable, 'sshd')
      provider.disable
    end
  end

  context "#running?" do
    it "should run rcctl check to check the service" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:check, 'sshd').and_return('sshd(ok)')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'check', 'sshd'], :failonfail => false, :combine => false, :squelch => false).and_return('sshd(ok)')
      expect(provider.running?).to be_truthy
    end

    it "should return true if the service is running" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:check, 'sshd').and_return('sshd(ok)')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'check', 'sshd'], :failonfail => false, :combine => false, :squelch => false).and_return('sshd(ok)')
      expect(provider.running?).to be_truthy
    end

    it "should return nil if the service is not running" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:check, 'sshd').and_return('sshd(failed)')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'check', 'sshd'], :failonfail => false, :combine => false, :squelch => false).and_return('sshd(failed)')
      expect(provider.running?).to be_nil
    end
  end

  context "#flags" do
    it "should return flags when set" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :flags => '-6'))
      allow(provider_class).to receive(:rcctl).with('get', 'sshd', 'flags').and_return('-6')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'get', 'sshd', 'flags'], :failonfail => false, :combine => false, :squelch => false).and_return('-6')
      provider.flags
    end

    it "should return empty flags" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with('get', 'sshd', 'flags').and_return('')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'get', 'sshd', 'flags'], :failonfail => false, :combine => false, :squelch => false).and_return('')
      provider.flags
    end

    it "should return flags for special services" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'pf'))
      allow(provider_class).to receive(:rcctl).with('get', 'pf', 'flags').and_return('YES')
      expect(provider).to receive(:execute).with(['/usr/sbin/rcctl', 'get', 'pf', 'flags'], :failonfail => false, :combine => false, :squelch => false).and_return('YES')
      provider.flags
    end
  end

  context "#flags=" do
    it "should run rcctl to set flags", unless: Puppet::Util::Platform.windows? || RUBY_PLATFORM == 'java' do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(provider_class).to receive(:rcctl).with(:set, 'sshd', :flags, '-4').and_return('')
      expect(provider).to receive(:rcctl).with(:set, 'sshd', :flags, '-4')
      provider.flags = '-4'
    end
  end
end
