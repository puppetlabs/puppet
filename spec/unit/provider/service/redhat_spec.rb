require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Redhat',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:redhat) }

  # `execute` and `texecute` start a new process, consequently setting $CHILD_STATUS to a Process::Status instance,
  # but because they are mocked, an external process is never executed and $CHILD_STATUS remain nil.
  # In order to execute some parts of the code under test and to mock $CHILD_STATUS, we need this variable to be a
  # Process::Status instance. We can achieve this by starting a process that does nothing (exit 0). By doing this,
  # $CHILD_STATUS will be initialised with a instance of Process::Status and we will be able to mock it.
  before(:all) do
    `exit 0`
  end

  before :each do
    @class = Puppet::Type.type(:service).provider(:redhat)
    @resource = double('resource')
    allow(@resource).to receive(:[]).and_return(nil)
    allow(@resource).to receive(:[]).with(:name).and_return("myservice")
    @provider = provider_class.new
    allow(@resource).to receive(:provider).and_return(@provider)
    @provider.resource = @resource
    allow(@provider).to receive(:get).with(:hasstatus).and_return(false)
    allow(FileTest).to receive(:file?).with('/sbin/service').and_return(true)
    allow(FileTest).to receive(:executable?).with('/sbin/service').and_return(true)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return('CentOS')
    allow(Facter).to receive(:value).with(:osfamily).and_return('RedHat')
  end

  osfamilies = [ 'RedHat' ]

  osfamilies.each do |osfamily|
    it "should be the default provider on #{osfamily}" do
      expect(Facter).to receive(:value).with(:osfamily).and_return(osfamily)
      expect(provider_class.default?).to be_truthy
    end
  end

  it "should be the default provider on sles11" do
    allow(Facter).to receive(:value).with(:osfamily).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:suse)
    allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("11")
    expect(provider_class.default?).to be_truthy
  end

  # test self.instances
  context "when getting all service instances" do
    before :each do
      @services = ['one', 'two', 'three', 'four', 'kudzu', 'functions', 'halt', 'killall', 'single', 'linuxconf', 'boot', 'reboot']
      @not_services = ['functions', 'halt', 'killall', 'single', 'linuxconf', 'reboot', 'boot']
      allow(Dir).to receive(:entries).and_return(@services)
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:executable?).and_return(true)
    end

    it "should return instances for all services" do
      (@services-@not_services).each do |inst|
        expect(@class).to receive(:new).with(hash_including(name: inst, path: '/etc/init.d')).and_return("#{inst}_instance")
      end
      results = (@services-@not_services).collect {|x| "#{x}_instance"}
      expect(@class.instances).to eq(results)
    end

    it "should call service status when initialized from provider" do
      allow(@resource).to receive(:[]).with(:status).and_return(nil)
      allow(@provider).to receive(:get).with(:hasstatus).and_return(true)
      expect(@provider).to receive(:execute)
        .with(['/sbin/service', 'myservice', 'status'], any_args)
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      @provider.send(:status)
    end
  end

  it "should use '--add' and 'on' when calling enable" do
    expect(provider_class).to receive(:chkconfig).with("--add", @resource[:name])
    expect(provider_class).to receive(:chkconfig).with(@resource[:name], :on)
    @provider.enable
  end

  it "(#15797) should explicitly turn off the service in all run levels" do
    expect(provider_class).to receive(:chkconfig).with("--level", "0123456", @resource[:name], :off)
    @provider.disable
  end

  it "should have an enabled? method" do
    expect(@provider).to respond_to(:enabled?)
  end

  context "when checking enabled? on Suse" do
    before :each do
      expect(Facter).to receive(:value).with(:osfamily).and_return('Suse')
    end

    it "should check for on" do
      allow(provider_class).to receive(:chkconfig).with(@resource[:name]).and_return("#{@resource[:name]}  on")
      expect(@provider.enabled?).to eq(:true)
    end

    it "should check for B" do
      allow(provider_class).to receive(:chkconfig).with(@resource[:name]).and_return("#{@resource[:name]}  B")
      expect(@provider.enabled?).to eq(:true)
    end

    it "should check for off" do
      allow(provider_class).to receive(:chkconfig).with(@resource[:name]).and_return("#{@resource[:name]}  off")
      expect(@provider.enabled?).to eq(:false)
    end

    it "should check for unknown service" do
      allow(provider_class).to receive(:chkconfig).with(@resource[:name]).and_return("#{@resource[:name]}: unknown service")
      expect(@provider.enabled?).to eq(:false)
    end
  end

  it "should have an enable method" do
    expect(@provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(@provider).to respond_to(:disable)
  end

  [:start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      expect(@provider).to respond_to(method)
    end

    describe "when running #{method}" do
      it "should use any provided explicit command" do
        allow(@resource).to receive(:[]).with(method).and_return("/user/specified/command")
        expect(@provider).to receive(:execute)
          .with(["/user/specified/command"], any_args)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        @provider.send(method)
      end

      it "should execute the service script with #{method} when no explicit command is provided" do
        allow(@resource).to receive(:[]).with("has#{method}".intern).and_return(:true)
        expect(@provider).to receive(:execute)
          .with(['/sbin/service', 'myservice', method.to_s], any_args)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        @provider.send(method)
      end
    end
  end

  context "when checking status" do
    context "when hasstatus is :true" do
      before :each do
        allow(@resource).to receive(:[]).with(:hasstatus).and_return(:true)
      end

      it "should execute the service script with fail_on_failure false" do
        expect(@provider).to receive(:execute)
          .with(['/sbin/service', 'myservice', 'status'], any_args)
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        @provider.status
      end

      it "should consider the process running if the command returns 0" do
        expect(@provider).to receive(:execute)
          .with(['/sbin/service', 'myservice', 'status'], hash_including(failonfail: false))
          .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
        expect(@provider.status).to eq(:running)
      end

      [-10,-1,1,10].each { |ec|
        it "should consider the process stopped if the command returns something non-0" do
          expect(@provider).to receive(:execute)
            .with(['/sbin/service', 'myservice', 'status'], hash_including(failonfail: false))
            .and_return(Puppet::Util::Execution::ProcessOutput.new('', ec))
          expect(@provider.status).to eq(:stopped)
        end
      }
    end

    context "when hasstatus is not :true" do
      it "should consider the service :running if it has a pid" do
        expect(@provider).to receive(:getpid).and_return("1234")
        expect(@provider.status).to eq(:running)
      end

      it "should consider the service :stopped if it doesn't have a pid" do
        expect(@provider).to receive(:getpid).and_return(nil)
        expect(@provider.status).to eq(:stopped)
      end
    end
  end

  context "when restarting and hasrestart is not :true" do
    it "should stop and restart the process with the server script" do
      expect(@provider).to receive(:execute).with(['/sbin/service', 'myservice', 'stop'], hash_including(failonfail: true))
      expect(@provider).to receive(:execute).with(['/sbin/service', 'myservice', 'start'], hash_including(failonfail: true))
      @provider.restart
    end
  end
end
