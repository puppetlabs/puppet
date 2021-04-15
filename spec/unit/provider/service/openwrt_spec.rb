require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Openwrt',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:openwrt) }

  let(:resource) do
    resource = double('resource')
    allow(resource).to receive(:[]).and_return(nil)
    allow(resource).to receive(:[]).with(:name).and_return("myservice")
    allow(resource).to receive(:[]).with(:path).and_return(["/etc/init.d"])

    resource
  end

  let(:provider) do
    provider = provider_class.new
    allow(provider).to receive(:get).with(:hasstatus).and_return(false)

    provider
  end

  before :each do
    allow(resource).to receive(:provider).and_return(provider)
    provider.resource = resource

    allow(FileTest).to receive(:file?).with('/etc/rc.common').and_return(true)
    allow(FileTest).to receive(:executable?).with('/etc/rc.common').and_return(true)

    # All OpenWrt tests operate on the init script directly. It must exist.
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with('/etc/init.d').and_return(true)

    allow(Puppet::FileSystem).to receive(:exist?).with('/etc/init.d/myservice').and_return(true)
    allow(FileTest).to receive(:file?).and_call_original
    allow(FileTest).to receive(:file?).with('/etc/init.d/myservice').and_return(true)
    allow(FileTest).to receive(:executable?).with('/etc/init.d/myservice').and_return(true)
  end

  operatingsystem = 'openwrt'
  it "should be the default provider on #{operatingsystem}" do
    expect(Facter).to receive(:value).with(:operatingsystem).and_return(operatingsystem)
    expect(provider_class.default?).to be_truthy
  end

  # test self.instances
  describe "when getting all service instances" do
    let(:services) {['dnsmasq', 'dropbear', 'firewall', 'led', 'puppet', 'uhttpd' ]}

    before :each do
      allow(Dir).to receive(:entries).and_call_original
      allow(Dir).to receive(:entries).with('/etc/init.d').and_return(services)
      allow(FileTest).to receive(:directory?).and_return(true)
      allow(FileTest).to receive(:executable?).and_return(true)
    end

    it "should return instances for all services" do
      services.each do |inst|
        expect(provider_class).to receive(:new).with(hash_including(:name => inst, :path => '/etc/init.d')).and_return("#{inst}_instance")
      end
      results = services.collect {|x| "#{x}_instance"}
      expect(provider_class.instances).to eq(results)
    end
  end

  it "should have an enabled? method" do
    expect(provider).to respond_to(:enabled?)
  end

  it "should have an enable method" do
    expect(provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(provider).to respond_to(:disable)
  end

  [:start, :stop, :restart].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end

    describe "when running #{method}" do
      it "should use any provided explicit command" do
        allow(resource).to receive(:[]).with(method).and_return("/user/specified/command")
        expect(provider).to receive(:execute).with(["/user/specified/command"], any_args)
        provider.send(method)
      end

      it "should execute the init script with #{method} when no explicit command is provided" do
        allow(resource).to receive(:[]).with("has#{method}".intern).and_return(:true)
        expect(provider).to receive(:execute).with(['/etc/init.d/myservice', method ], any_args)
        provider.send(method)
      end
    end
  end

  describe "when checking status" do
    it "should consider the service :running if it has a pid" do
      expect(provider).to receive(:getpid).and_return("1234")
      expect(provider.status).to eq(:running)
    end

    it "should consider the service :stopped if it doesn't have a pid" do
      expect(provider).to receive(:getpid).and_return(nil)
      expect(provider.status).to eq(:stopped)
    end
  end
end
