require 'spec_helper'

# Note that much of the functionality of the dnf provider is already tested with yum provider tests,
# as yum is the parent provider.

provider_class = Puppet::Type.type(:package).provider(:dnf)

context 'default' do
  [ 19, 20, 21 ].each do |ver|
    it "should not be the default provider on fedora#{ver}" do
      Facter.stubs(:value).with(:osfamily).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns(:fedora)
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
      expect(provider_class).to_not be_default
    end
  end

  [ 22, 23, 24 ].each do |ver|
    it "should be the default provider on fedora#{ver}" do
      Facter.stubs(:value).with(:osfamily).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns(:fedora)
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
      expect(provider_class).to be_default
    end
  end
end

describe provider_class do
  let(:name) { 'mypackage' }
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name => name,
      :ensure => :installed,
      :provider => 'dnf'
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  before do
    provider_class.stubs(:command).with(:cmd).returns('/usr/bin/dnf')
    provider.stubs(:rpm).returns 'rpm'
    provider.stubs(:get).with(:version).returns '1'
    provider.stubs(:get).with(:release).returns '1'
    provider.stubs(:get).with(:arch).returns 'i386'
  end

  describe 'provider features' do
    it { is_expected.to be_versionable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_virtual_packages }
  end

  describe "default provider" do
    before do
      Facter.expects(:value).with(:operatingsystem).returns("fedora")
    end

    it "should be the default provider on Fedora 22" do
      Facter.expects(:value).with(:operatingsystemmajrelease).returns('22')
      expect(described_class.default?).to be_truthy
    end

    it "should be the default provider on Fedora 23" do
      Facter.expects(:value).with(:operatingsystemmajrelease).returns('23')
      expect(described_class.default?).to be_truthy
    end
  end

  # provider should repond to the following methods
   [:install, :latest, :update, :purge, :install_options].each do |method|
     it "should have a(n) #{method}" do
       expect(provider).to respond_to(method)
    end
  end

  describe 'when installing' do
    before(:each) do
      Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
      provider.stubs(:which).with("rpm").returns("/bin/rpm")
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).returns("4.10.1\n").at_most_once
      Facter.stubs(:value).with(:operatingsystemmajrelease).returns('22')
    end

    it 'should call dnf install for :installed' do
      resource.stubs(:should).with(:ensure).returns :installed
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/dnf', '-d', '0', '-e', '1', '-y', :install, 'mypackage'])
      provider.install
    end

    it 'should be able to downgrade' do
      current_version = '1.2'
      version = '1.0'
      resource[:ensure] = '1.0'
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/dnf', '-d', '0', '-e', '1', '-y', :downgrade, "#{name}-#{version}"])
      provider.stubs(:query).returns(:ensure => current_version).then.returns(:ensure => version)
      provider.install
    end

    it 'should accept install options' do
      resource[:ensure] = :installed
      resource[:install_options] = ['-t', {'-x' => 'expackage'}]

      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/dnf', '-d', '0', '-e', '1', '-y', ['-t', '-x=expackage'], :install, name])
      provider.install
    end
  end

  describe 'when uninstalling' do
    it 'should use erase to purge' do
      Puppet::Util::Execution.expects(:execute).with(['/usr/bin/dnf', '-y', :erase, name])
      provider.purge
    end
  end

  describe "executing yum check-update" do
    it "passes repos to enable to 'yum check-update'" do
      Puppet::Util::Execution.expects(:execute).with do |args, *rest|
        expect(args).to eq %w[/usr/bin/dnf check-update --enablerepo=updates --enablerepo=fedoraplus]
      end.returns(stub(:exitstatus => 0))
      described_class.check_updates(%w[updates fedoraplus], [], [])
    end
  end
end
