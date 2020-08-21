require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Daemontools',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:daemontools) }

  before(:each) do
    # Create a mock resource
    @resource = double('resource')

    @provider = provider_class.new
    @servicedir = "/etc/service"
    @provider.servicedir=@servicedir
    @daemondir = "/var/lib/service"
    @provider.class.defpath=@daemondir

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name, source and path (because we won't run
    # the thing that will fetch the resource path from the provider)
    allow(@resource).to receive(:[]).with(:name).and_return("myservice")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:enabled)
    allow(@resource).to receive(:[]).with(:path).and_return(@daemondir)
    allow(@resource).to receive(:ref).and_return("Service[myservice]")

    @provider.resource = @resource

    allow(@provider).to receive(:command).with(:svc).and_return("svc")
    allow(@provider).to receive(:command).with(:svstat).and_return("svstat")

    allow(@provider).to receive(:svc)
    allow(@provider).to receive(:svstat)
  end

  it "should have a restart method" do
    expect(@provider).to respond_to(:restart)
  end

  it "should have a start method" do
    expect(@provider).to respond_to(:start)
  end

  it "should have a stop method" do
    expect(@provider).to respond_to(:stop)
  end

  it "should have an enabled? method" do
    expect(@provider).to respond_to(:enabled?)
  end

  it "should have an enable method" do
    expect(@provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(@provider).to respond_to(:disable)
  end

  context "when starting" do
    it "should use 'svc' to start the service" do
      allow(@provider).to receive(:enabled?).and_return(:true)
      expect(@provider).to receive(:svc).with("-u", "/etc/service/myservice")

      @provider.start
    end

    it "should enable the service if it is not enabled" do
      allow(@provider).to receive(:svc)

      expect(@provider).to receive(:enabled?).and_return(:false)
      expect(@provider).to receive(:enable)

      @provider.start
    end
  end

  context "when stopping" do
    it "should use 'svc' to stop the service" do
      allow(@provider).to receive(:disable)
      expect(@provider).to receive(:svc).with("-d", "/etc/service/myservice")

      @provider.stop
    end
  end

  context "when restarting" do
    it "should use 'svc' to restart the service" do
      expect(@provider).to receive(:svc).with("-t", "/etc/service/myservice")

      @provider.restart
    end
  end

  context "when enabling" do
    it "should create a symlink between daemon dir and service dir", :if => Puppet.features.manages_symlinks?  do
      daemon_path = File.join(@daemondir, "myservice")
      service_path = File.join(@servicedir, "myservice")
      expect(Puppet::FileSystem).to receive(:symlink?).with(service_path).and_return(false)
      expect(Puppet::FileSystem).to receive(:symlink).with(daemon_path, service_path).and_return(0)

      @provider.enable
    end
  end

  context "when disabling" do
    it "should remove the symlink between daemon dir and service dir" do
      allow(FileTest).to receive(:directory?).and_return(false)
      path = File.join(@servicedir,"myservice")
      expect(Puppet::FileSystem).to receive(:symlink?).with(path).and_return(true)
      expect(Puppet::FileSystem).to receive(:unlink).with(path)
      allow(@provider).to receive(:texecute).and_return("")
      @provider.disable
    end

    it "should stop the service" do
      allow(FileTest).to receive(:directory?).and_return(false)
      expect(Puppet::FileSystem).to receive(:symlink?).and_return(true)
      allow(Puppet::FileSystem).to receive(:unlink)
      expect(@provider).to receive(:stop)
      @provider.disable
    end
  end

  context "when checking if the service is enabled?" do
    it "should return true if it is running" do
      allow(@provider).to receive(:status).and_return(:running)

      expect(@provider.enabled?).to eq(:true)
    end

    [true, false].each do |t|
      it "should return #{t} if the symlink exists" do
        allow(@provider).to receive(:status).and_return(:stopped)
        path = File.join(@servicedir,"myservice")
        expect(Puppet::FileSystem).to receive(:symlink?).with(path).and_return(t)

        expect(@provider.enabled?).to eq("#{t}".to_sym)
      end
    end
  end

  context "when checking status" do
    it "should call the external command 'svstat /etc/service/myservice'" do
      expect(@provider).to receive(:svstat).with(File.join(@servicedir,"myservice"))
      @provider.status
    end
  end

  context "when checking status" do
    it "and svstat fails, properly raise a Puppet::Error" do
      expect(@provider).to receive(:svstat).with(File.join(@servicedir,"myservice")).and_raise(Puppet::ExecutionFailure, "failure")
      expect { @provider.status }.to raise_error(Puppet::Error, 'Could not get status for service Service[myservice]: failure')
    end

    it "and svstat returns up, then return :running" do
      expect(@provider).to receive(:svstat).with(File.join(@servicedir,"myservice")).and_return("/etc/service/myservice: up (pid 454) 954326 seconds")
      expect(@provider.status).to eq(:running)
    end

    it "and svstat returns not running, then return :stopped" do
      expect(@provider).to receive(:svstat).with(File.join(@servicedir,"myservice")).and_return("/etc/service/myservice: supervise not running")
      expect(@provider.status).to  eq(:stopped)
    end
  end

  context '.instances' do
    before do
      allow(provider_class).to receive(:defpath).and_return(path)
    end

    context 'when defpath is nil' do
      let(:path) { nil }

      it 'returns info message' do
        expect(Puppet).to receive(:info).with(/daemontools is unsuitable because service directory is nil/)
        provider_class.instances
      end
    end

    context 'when defpath does not exist' do
      let(:path) { '/inexistent_path' }

      it 'returns notice about missing path' do
        expect(Puppet).to receive(:notice).with(/Service path #{path} does not exist/)
        provider_class.instances
      end
    end
  end
end
