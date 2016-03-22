#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:yum)

describe provider_class do
  let(:name) { 'mypackage' }
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => name,
      :ensure   => :installed,
      :provider => 'yum'
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  before do
    provider.stubs(:yum).returns 'yum'
    provider.stubs(:rpm).returns 'rpm'
    provider.stubs(:get).with(:version).returns '1'
    provider.stubs(:get).with(:release).returns '1'
    provider.stubs(:get).with(:arch).returns 'i386'
  end

  describe 'provider features' do
    it { should be_versionable }
    it { should be_install_options }
    it { should be_virtual_packages }
  end

  # provider should repond to the following methods
   [:install, :latest, :update, :purge, :install_options].each do |method|
     it "should have a(n) #{method}" do
       provider.should respond_to(method)
    end
  end

  describe 'when installing' do
    before(:each) do
      Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
      provider.stubs(:which).with("rpm").returns("/bin/rpm")
      Puppet::Util::Execution.expects(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).returns("4.10.1\n").at_most_once
    end

    it 'should call yum install for :installed' do
      resource.stubs(:should).with(:ensure).returns :installed
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :list, name)
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, name)
      provider.install
    end

    it 'should use :install to update' do
      provider.expects(:install)
      provider.update
    end

    it 'should be able to set version' do
      version = '1.2'
      resource[:ensure] = version
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :list, name)
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, "#{name}-#{version}")
      provider.stubs(:query).returns :ensure => version
      provider.install
    end

    it 'should be able to downgrade' do
      current_version = '1.2'
      version = '1.0'
      resource[:ensure] = '1.0'
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :downgrade, "#{name}-#{version}")
      provider.stubs(:query).returns(:ensure => current_version).then.returns(:ensure => version)
      provider.install
    end

    it 'should accept install options' do
      resource[:ensure] = :installed
      resource[:install_options] = ['-t', {'-x' => 'expackage'}]

      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', ['-t', '-x=expackage'], :list, name)
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', ['-t', '-x=expackage'], :install, name)
      provider.install
    end

    it 'allow virtual packages' do
      resource[:ensure] = :installed
      resource[:allow_virtual] = true
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :list, name).never
      provider.expects(:yum).with('-d', '0', '-e', '0', '-y', :install, name)
      provider.install
    end
  end

  describe 'when uninstalling' do
    it 'should use erase to purge' do
      provider.expects(:yum).with('-y', :erase, name)
      provider.purge
    end
  end

  it 'should be versionable' do
    provider.should be_versionable
  end

  describe 'determining the latest version available for a package' do

    it "passes the value of enablerepo install_options when querying" do
      resource[:install_options] = [
        {'--enablerepo' => 'contrib'},
        {'--enablerepo' => 'centosplus'},
      ]
      provider.stubs(:properties).returns({:ensure => '3.4.5'})

      described_class.expects(:latest_package_version).with(name, ['contrib', 'centosplus'], [])
      provider.latest
    end

    it "passes the value of disablerepo install_options when querying" do
      resource[:install_options] = [
        {'--disablerepo' => 'updates'},
        {'--disablerepo' => 'centosplus'},
      ]
      provider.stubs(:properties).returns({:ensure => '3.4.5'})

      described_class.expects(:latest_package_version).with(name, [], ['updates', 'centosplus'])
      provider.latest
    end

    describe 'and a newer version is not available' do
      before :each do
        described_class.stubs(:latest_package_version).with(name, [], []).returns nil
      end

      it 'raises an error the package is not installed' do
        provider.stubs(:properties).returns({:ensure => :absent})
        expect {
          provider.latest
        }.to raise_error(Puppet::DevError, 'Tried to get latest on a missing package')
      end

      it 'returns version of the currently installed package' do
        provider.stubs(:properties).returns({:ensure => '3.4.5'})
        provider.latest.should == '3.4.5'
      end
    end

    describe 'and a newer version is available' do
      let(:latest_version) do
        {
          :name     => name,
          :epoch    => '1',
          :version  => '2.3.4',
          :release  => '5',
          :arch     => 'i686',
        }
      end

      it 'includes the epoch in the version string' do
        described_class.stubs(:latest_package_version).with(name, [], []).returns(latest_version)
        provider.latest.should == '1:2.3.4-5'
      end
    end
  end

  describe "lazy loading of latest package versions" do
    before { described_class.clear }
    after { described_class.clear }

    let(:mypackage_version) do
      {
        :name     => name,
        :epoch    => '1',
        :version  => '2.3.4',
        :release  => '5',
        :arch     => 'i686',
      }
    end

    let(:mypackage_newerversion) do
      {
        :name     => name,
        :epoch    => '1',
        :version  => '4.5.6',
        :release  => '7',
        :arch     => 'i686',
      }
    end

    let(:latest_versions) { {name => [mypackage_version]} }
    let(:enabled_versions) { {name => [mypackage_newerversion]} }

    it "returns the version hash if the package was found" do
      described_class.expects(:fetch_latest_versions).with([], []).once.returns(latest_versions)
      version = described_class.latest_package_version(name, [], [])
      expect(version).to eq(mypackage_version)
    end

    it "is nil if the package was not found in the query" do
      described_class.expects(:fetch_latest_versions).with([], []).once.returns(latest_versions)
      version = described_class.latest_package_version('nopackage', [], [])
      expect(version).to be_nil
    end

    it "caches the package list and reuses that for subsequent queries" do
      described_class.expects(:fetch_latest_versions).with([], []).once.returns(latest_versions)

      2.times {
        version = described_class.latest_package_version(name, [], [])
        expect(version).to eq mypackage_version
      }
    end

    it "caches separate lists for each combination of 'enablerepo' and 'disablerepo'" do
      described_class.expects(:fetch_latest_versions).with([], []).once.returns(latest_versions)
      described_class.expects(:fetch_latest_versions).with(['enabled'], ['disabled']).once.returns(enabled_versions)

      2.times {
        version = described_class.latest_package_version(name, [], [])
        expect(version).to eq mypackage_version
      }

      2.times {
        version = described_class.latest_package_version(name, ['enabled'], ['disabled'])
        expect(version).to eq(mypackage_newerversion)
      }
    end
  end

  describe "querying for the latest version of all packages" do
    let(:yumhelper_single_arch) do
      <<-YUMHELPER_OUTPUT
 * base: centos.tcpdiag.net
 * extras: centos.mirrors.hoobly.com
 * updates: mirrors.arsc.edu
_pkg nss-tools 0 3.14.3 4.el6_4 x86_64
_pkg pixman 0 0.26.2 5.el6_4 x86_64
_pkg myresource 0 1.2.3.4 5.el4 noarch
_pkg mysummaryless 0 1.2.3.4 5.el4 noarch
     YUMHELPER_OUTPUT
    end

    let(:yumhelper_multi_arch) do
      yumhelper_single_arch + <<-YUMHELPER_OUTPUT
_pkg nss-tools 0 3.14.3 4.el6_4 i386
_pkg pixman 0 0.26.2 5.el6_4 i386
      YUMHELPER_OUTPUT
    end


    it "creates an entry for each line that's prefixed with '_pkg'" do
      described_class.expects(:python).with([described_class::YUMHELPER]).returns(yumhelper_single_arch)
      entries = described_class.fetch_latest_versions([], [])
      expect(entries.keys).to include 'nss-tools'
      expect(entries.keys).to include 'pixman'
      expect(entries.keys).to include 'myresource'
      expect(entries.keys).to include 'mysummaryless'
    end

    it "creates an entry for each package name and architecture" do
      described_class.expects(:python).with([described_class::YUMHELPER]).returns(yumhelper_single_arch)
      entries = described_class.fetch_latest_versions([], [])
      expect(entries.keys).to include 'nss-tools.x86_64'
      expect(entries.keys).to include 'pixman.x86_64'
      expect(entries.keys).to include 'myresource.noarch'
      expect(entries.keys).to include 'mysummaryless.noarch'
    end

    it "stores multiple entries if a package is build for multiple architectures" do
      described_class.expects(:python).with([described_class::YUMHELPER]).returns(yumhelper_multi_arch)
      entries = described_class.fetch_latest_versions([], [])
      expect(entries.keys).to include 'nss-tools.x86_64'
      expect(entries.keys).to include 'pixman.x86_64'
      expect(entries.keys).to include 'nss-tools.i386'
      expect(entries.keys).to include 'pixman.i386'

      expect(entries['nss-tools']).to have(2).items
      expect(entries['pixman']).to have(2).items
    end

    it "passes the repos to enable to the helper" do
      described_class.expects(:python).with do |script, *args|
        expect(script).to eq described_class::YUMHELPER
        expect(args).to eq %w[-e updates -e centosplus]
      end.returns('')
      described_class.fetch_latest_versions(['updates', 'centosplus'], [])
    end

    it "passes the repos to disable to the helper" do
      described_class.expects(:python).with do |script, *args|
        expect(script).to eq described_class::YUMHELPER
        expect(args).to eq %w[-d updates -d centosplus]
      end.returns('')
      described_class.fetch_latest_versions([], ['updates', 'centosplus'])
    end

    it 'passes a combination of repos to the helper' do
      described_class.expects(:python).with do |script, *args|
        expect(script).to eq described_class::YUMHELPER
        expect(args).to eq %w[-e os -e contrib -d updates -d centosplus]
      end.returns('')
      described_class.fetch_latest_versions(['os', 'contrib'], ['updates', 'centosplus'])
    end
  end
end
