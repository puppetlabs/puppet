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
      described_class.expects(:check_updates).with([], []).once.returns(latest_versions)
      version = described_class.latest_package_version(name, [], [])
      expect(version).to eq(mypackage_version)
    end

    it "is nil if the package was not found in the query" do
      described_class.expects(:check_updates).with([], []).once.returns(latest_versions)
      version = described_class.latest_package_version('nopackage', [], [])
      expect(version).to be_nil
    end

    it "caches the package list and reuses that for subsequent queries" do
      described_class.expects(:check_updates).with([], []).once.returns(latest_versions)

      2.times {
        version = described_class.latest_package_version(name, [], [])
        expect(version).to eq mypackage_version
      }
    end

    it "caches separate lists for each combination of 'enablerepo' and 'disablerepo'" do
      described_class.expects(:check_updates).with([], []).once.returns(latest_versions)
      described_class.expects(:check_updates).with(['enabled'], ['disabled']).once.returns(enabled_versions)

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

  describe "executing yum check-update" do
    before do
      described_class.stubs(:command).with(:yum).returns '/usr/bin/yum'
    end

    it "passes repos to enable to 'yum check-update'" do
      Puppet::Util::Execution.expects(:execute).with do |args, *rest|
        expect(args).to eq %w[/usr/bin/yum check-update -e updates -e centosplus]
      end.returns(stub(:exitstatus => 0))
      described_class.check_updates(%w[updates centosplus], [])
    end

    it "passes repos to disable to 'yum check-update'" do
      Puppet::Util::Execution.expects(:execute).with do |args, *rest|
        expect(args).to eq %w[/usr/bin/yum check-update -d updates -d centosplus]
      end.returns(stub(:exitstatus => 0))
      described_class.check_updates([],%w[updates centosplus])
    end

    it "passes a combination of repos to enable and disable to 'yum check-update'" do
      Puppet::Util::Execution.expects(:execute).with do |args, *rest|
        expect(args).to eq %w[/usr/bin/yum check-update -e os -e contrib -d updates -d centosplus]
      end.returns(stub(:exitstatus => 0))
      described_class.check_updates(%w[os contrib], %w[updates centosplus])
    end

    it "returns an empty hash if 'yum check-update' returned 0" do
      Puppet::Util::Execution.expects(:execute).returns(stub :exitstatus => 0)
      expect(described_class.check_updates([], [])).to be_empty
    end

    it "returns a populated hash if 'yum check-update returned 100'" do
      output = stub(:exitstatus => 100)
      Puppet::Util::Execution.expects(:execute).returns(output)
      described_class.expects(:parse_updates).with(output).returns({:has => :updates})
      expect(described_class.check_updates([], [])).to eq({:has => :updates})
    end

    it "returns an empty hash if 'yum check-update' returned an exit code that was not 0 or 100" do
      Puppet::Util::Execution.expects(:execute).returns(stub(:exitstatus => 1))
      described_class.expects(:warn)
      expect(described_class.check_updates([], [])).to eq({})
    end
  end

  describe "parsing the output of check-update" do
    let(:check_update) do
      # Trailing whitespace is intentional
      <<-EOD
Loaded plugins: fastestmirror
Determining fastest mirrors
 * base: centos.sonn.com
 * epel: ftp.osuosl.org
 * extras: mirror.web-ster.com
 * updates: centos.sonn.com

curl.i686                               7.32.0-10.fc20           updates        
curl.x86_64                             7.32.0-10.fc20           updates        
gawk.i686                               4.1.0-3.fc20             updates        
dhclient.i686                           12:4.1.1-38.P1.fc20      updates        
selinux-policy.noarch                   3.12.1-163.fc20          updates-testing
      EOD
    end

    it 'creates an entry for each package keyed on the package name' do
      output = described_class.parse_updates(check_update)
      expect(output['curl']).to eq([{:name => 'curl', :epoch => '0', :version => '7.32.0', :release => '10.fc20', :arch => 'i686'}, {:name => 'curl', :epoch => '0', :version => '7.32.0', :release => '10.fc20', :arch => 'x86_64'}])
      expect(output['gawk']).to eq([{:name => 'gawk', :epoch => '0', :version => '4.1.0', :release => '3.fc20', :arch => 'i686'}])
      expect(output['dhclient']).to eq([{:name => 'dhclient', :epoch => '12', :version => '4.1.1', :release => '38.P1.fc20', :arch => 'i686'}])
      expect(output['selinux-policy']).to eq([{:name => 'selinux-policy', :epoch => '0', :version => '3.12.1', :release => '163.fc20', :arch => 'noarch'}])
    end

    it 'creates an entry for each package keyed on the package name and package architecture' do
      output = described_class.parse_updates(check_update)
      expect(output['curl.i686']).to eq([{:name => 'curl', :epoch => '0', :version => '7.32.0', :release => '10.fc20', :arch => 'i686'}])
      expect(output['curl.x86_64']).to eq([{:name => 'curl', :epoch => '0', :version => '7.32.0', :release => '10.fc20', :arch => 'x86_64'}])
      expect(output['gawk.i686']).to eq([{:name => 'gawk', :epoch => '0', :version => '4.1.0', :release => '3.fc20', :arch => 'i686'}])
      expect(output['dhclient.i686']).to eq([{:name => 'dhclient', :epoch => '12', :version => '4.1.1', :release => '38.P1.fc20', :arch => 'i686'}])
      expect(output['selinux-policy.noarch']).to eq([{:name => 'selinux-policy', :epoch => '0', :version => '3.12.1', :release => '163.fc20', :arch => 'noarch'}])
    end
  end

  describe "parsing a line from yum check-update" do
    it "splits up the package name and architecture fields" do
      checkupdate = "curl.i686                               7.32.0-10.fc20           updates"

      parsed = described_class.update_to_hash(checkupdate)
      expect(parsed[:name]).to eq 'curl'
      expect(parsed[:arch]).to eq 'i686'
    end

    it "splits up the epoch, version, and release fields" do
      checkupdate = "dhclient.i686                            12:4.1.1-38.P1.el6.centos       base"
      parsed = described_class.update_to_hash(checkupdate)
      expect(parsed[:epoch]).to eq '12'
      expect(parsed[:version]).to eq '4.1.1'
      expect(parsed[:release]).to eq '38.P1.el6.centos'
    end

    it "sets the epoch to 0 when an epoch is not specified" do
      checkupdate = "curl.i686                               7.32.0-10.fc20           updates"

      parsed = described_class.update_to_hash(checkupdate)
      expect(parsed[:epoch]).to eq '0'
      expect(parsed[:version]).to eq '7.32.0'
      expect(parsed[:release]).to eq '10.fc20'
    end
  end
end
