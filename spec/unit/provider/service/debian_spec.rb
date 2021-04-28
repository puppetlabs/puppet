require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Debian',
         unless: Puppet::Util::Platform.jruby? || Puppet::Util::Platform.windows? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:debian) }

  before(:all) do
    `exit 0`
  end

  before(:each) do
    # Create a mock resource
    @resource = double('resource')

    @provider = provider_class.new

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name, source and path
    allow(@resource).to receive(:[]).with(:name).and_return("myservice")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:enabled)
    allow(@resource).to receive(:ref).and_return("Service[myservice]")

    @provider.resource = @resource

    allow(@provider).to receive(:command).with(:update_rc).and_return("update_rc")
    allow(@provider).to receive(:command).with(:invoke_rc).and_return("invoke_rc")
    allow(@provider).to receive(:command).with(:service).and_return("service")

    allow(@provider).to receive(:update_rc)
    allow(@provider).to receive(:invoke_rc)
  end

  ['1','2'].each do |version|
    it "should be the default provider on CumulusLinux #{version}" do
      expect(Facter).to receive(:value).with(:operatingsystem).at_least(:once).and_return('CumulusLinux')
      expect(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return(version)
      expect(provider_class.default?).to be_truthy
    end
  end

  it "should be the default provider on Devuan" do
    expect(Facter).to receive(:value).with(:operatingsystem).at_least(:once).and_return('Devuan')
    expect(provider_class.default?).to be_truthy
  end

  it "should be the default provider on Debian" do
    expect(Facter).to receive(:value).with(:operatingsystem).at_least(:once).and_return('Debian')
    expect(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('7')
    expect(provider_class.default?).to be_truthy
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

  context "when enabling" do
    it "should call update-rc.d twice" do
      expect(@provider).to receive(:update_rc).twice
      @provider.enable
    end
  end

  context "when disabling" do
    it "should be able to disable services with newer sysv-rc versions" do
      allow(@provider).to receive(:`).with("dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?").and_return("0")

      expect(@provider).to receive(:update_rc).with(@resource[:name], "disable")

      @provider.disable
    end

    it "should be able to enable services with older sysv-rc versions" do
      allow(@provider).to receive(:`).with("dpkg --compare-versions $(dpkg-query -W --showformat '${Version}' sysv-rc) ge 2.88 ; echo $?").and_return("1")

      expect(@provider).to receive(:update_rc).with("-f", @resource[:name], "remove")
      expect(@provider).to receive(:update_rc).with(@resource[:name], "stop", "00", "1", "2", "3", "4", "5", "6", ".")

      @provider.disable
    end
  end

  context "when checking whether it is enabled" do
    it "should execute the query command" do
      expect(@provider).to receive(:execute).with("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start").and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      @provider.enabled?
    end

    it "should return true when invoke-rc.d exits with 104 status" do
      expect(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', 104))
      expect(@provider.enabled?).to eq(:true)
    end

    it "should return true when invoke-rc.d exits with 106 status" do
      expect(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', 106))
      expect(@provider.enabled?).to eq(:true)
    end

    shared_examples "manually queries service status" do |status|
      it "links count is 4" do
        allow(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', status))
        allow(@provider).to receive(:get_start_link_count).and_return(4)
        expect(@provider.enabled?).to eq(:true)
      end
      it "links count is less than 4" do
        allow(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', status))
        allow(@provider).to receive(:get_start_link_count).and_return(3)
        expect(@provider.enabled?).to eq(:false)
      end
    end

    context "when invoke-rc.d exits with 101 status" do
      it_should_behave_like "manually queries service status", 101
    end

    context "when invoke-rc.d exits with 105 status" do
      it_should_behave_like "manually queries service status", 105
    end

    context "when invoke-rc.d exits with 101 status" do
      it_should_behave_like "manually queries service status", 101
    end

    context "when invoke-rc.d exits with 105 status" do
      it_should_behave_like "manually queries service status", 105
    end

    # pick a range of non-[104.106] numbers, strings and booleans to test with.
    [-100, -1, 0, 1, 100, "foo", "", :true, :false].each do |exitstatus|
      it "should return false when invoke-rc.d exits with #{exitstatus} status" do
        allow(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', exitstatus))
        expect(@provider.enabled?).to eq(:false)
      end
    end
  end

  context "when checking service status" do
    it "should use the service command" do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('Debian')
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('8')
      allow(@resource).to receive(:[]).with(:hasstatus).and_return(:true)
      expect(@provider.statuscmd).to eq(["service", @resource[:name], "status"])
    end
  end
end
