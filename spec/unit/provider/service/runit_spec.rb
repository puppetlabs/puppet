require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Runit',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:runit) }

  before(:each) do
    # Create a mock resource
    @resource = double('resource')

    @provider = provider_class.new
    @servicedir = "/etc/service"
    @provider.servicedir=@servicedir
    @daemondir = "/etc/sv"
    @provider.class.defpath=@daemondir

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name, source and path (because we won't run
    # the thing that will fetch the resource path from the provider)
    allow(@resource).to receive(:[]).with(:name).and_return("myservice")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:enabled)
    allow(@resource).to receive(:[]).with(:path).and_return(@daemondir)
    allow(@resource).to receive(:ref).and_return("Service[myservice]")

    allow(@provider).to receive(:sv)

    allow(@provider).to receive(:resource).and_return(@resource)
  end

  it "should have a restart method" do
    expect(@provider).to respond_to(:restart)
  end

  it "should have a restartcmd method" do
    expect(@provider).to respond_to(:restartcmd)
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
    it "should enable the service if it is not enabled" do
      allow(@provider).to receive(:sv)

      expect(@provider).to receive(:enabled?).and_return(:false)
      expect(@provider).to receive(:enable)
      allow(@provider).to receive(:sleep)

      @provider.start
    end

    it "should execute external command 'sv start /etc/service/myservice'" do
      allow(@provider).to receive(:enabled?).and_return(:true)
      expect(@provider).to receive(:sv).with("start", "/etc/service/myservice")
      @provider.start
    end
  end

  context "when stopping" do
    it "should execute external command 'sv stop /etc/service/myservice'" do
      expect(@provider).to receive(:sv).with("stop", "/etc/service/myservice")
      @provider.stop
    end
  end

  context "when restarting" do
    it "should call 'sv restart /etc/service/myservice'" do
      expect(@provider).to receive(:sv).with("restart","/etc/service/myservice")
      @provider.restart
    end
  end

  context "when enabling" do
    it "should create a symlink between daemon dir and service dir", :if => Puppet.features.manages_symlinks? do
      daemon_path = File.join(@daemondir,"myservice")
      service_path = File.join(@servicedir,"myservice")
      expect(Puppet::FileSystem).to receive(:symlink?).with(service_path).and_return(false)
      expect(Puppet::FileSystem).to receive(:symlink).with(daemon_path, File.join(@servicedir,"myservice")).and_return(0)
      @provider.enable
    end
  end

  context "when disabling" do
    it "should remove the '/etc/service/myservice' symlink" do
      path = File.join(@servicedir,"myservice")
      allow(FileTest).to receive(:directory?).and_return(false)
      expect(Puppet::FileSystem).to receive(:symlink?).with(path).and_return(true)
      expect(Puppet::FileSystem).to receive(:unlink).with(path).and_return(0)
      @provider.disable
    end
  end

  context "when checking status" do
    it "should call the external command 'sv status /etc/sv/myservice'" do
      expect(@provider).to receive(:sv).with('status',File.join(@daemondir,"myservice"))
      @provider.status
    end
  end

  context "when checking status" do
    it "and sv status fails, properly raise a Puppet::Error" do
      expect(@provider).to receive(:sv).with('status',File.join(@daemondir,"myservice")).and_raise(Puppet::ExecutionFailure, "fail: /etc/sv/myservice: file not found")
      expect { @provider.status }.to raise_error(Puppet::Error, 'Could not get status for service Service[myservice]: fail: /etc/sv/myservice: file not found')
    end

    it "and sv status returns up, then return :running" do
      expect(@provider).to receive(:sv).with('status',File.join(@daemondir,"myservice")).and_return("run: /etc/sv/myservice: (pid 9029) 6s")
      expect(@provider.status).to eq(:running)
    end

    it "and sv status returns not running, then return :stopped" do
      expect(@provider).to receive(:sv).with('status',File.join(@daemondir,"myservice")).and_return("fail: /etc/sv/myservice: runsv not running")
      expect(@provider.status).to eq(:stopped)
    end

    it "and sv status returns a warning, then return :stopped" do
      expect(@provider).to receive(:sv).with('status',File.join(@daemondir,"myservice")).and_return("warning: /etc/sv/myservice: unable to open supervise/ok: file does not exist")
      expect(@provider.status).to eq(:stopped)
    end
  end

  context '.instances' do
    before do
      allow(provider_class).to receive(:defpath).and_return(path)
    end

    context 'when defpath is nil' do
      let(:path) { nil }

      it 'returns info message' do
        expect(Puppet).to receive(:info).with(/runit is unsuitable because service directory is nil/)
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
