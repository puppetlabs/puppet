require 'spec_helper'
require 'puppet/provider/package/pkgng'

describe Puppet::Type.type(:package).provider(:pkgng) do
  let(:name) { 'bash' }
  let(:installed_name) { 'zsh' }
  let(:pkgng) { 'pkgng' }

  let(:resource) do
    # When bash is not present
    Puppet::Type.type(:package).new(:name => name, :provider => pkgng)
  end

  let(:installed_resource) do
    # When zsh is present
    Puppet::Type.type(:package).new(:name => installed_name, :provider => pkgng)
  end

  let(:latest_resource) do
    # When curl is installed but not the latest
    Puppet::Type.type(:package).new(:name => 'ftp/curl', :provider => pkgng, :ensure => latest)
  end

  let (:provider) { resource.provider }
  let (:installed_provider) { installed_resource.provider }

  def run_in_catalog(*resources)
    catalog = Puppet::Resource::Catalog.new
    catalog.host_config = false
    resources.each do |resource|
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  before do
    allow(described_class).to receive(:command).with(:pkg).and_return('/usr/local/sbin/pkg')

    info = File.read(my_fixture('pkg.query'))
    allow(described_class).to receive(:get_query).and_return(info)

    version_list = File.read(my_fixture('pkg.version'))
    allow(described_class).to receive(:get_version_list).and_return(version_list)
  end

  context "#instances" do
    it "should return the empty set if no packages are listed" do
      allow(described_class).to receive(:get_query).and_return('')
      allow(described_class).to receive(:get_version_list).and_return('')
      expect(described_class.instances).to be_empty
    end

    it "should return all packages when invoked" do
      expect(described_class.instances.map(&:name).sort).to eq(
        %w{ca_root_nss curl nmap pkg gnupg zsh tac_plus}.sort)
    end

    it "should set latest to current version when no upgrade available" do
      nmap = described_class.instances.find {|i| i.properties[:origin] == 'security/nmap' }

      expect(nmap.properties[:version]).to eq(nmap.properties[:latest])
    end

    it "should return an empty array when pkg calls raise an exception" do
      allow(described_class).to receive(:get_query).and_raise(Puppet::ExecutionFailure, 'An error occurred.')
      expect(described_class.instances).to eq([])
    end

    describe "version" do
      it "should retrieve the correct version of the current package" do
        zsh = described_class.instances.find {|i| i.properties[:origin] == 'shells/zsh' }
        expect(zsh.properties[:version]).to eq('5.0.2_1')
      end
    end
  end

  context "#install" do
    it "should call pkg with the specified package version given an origin for package name" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'ftp/curl',
        :provider => :pkgng,
        :ensure   => '7.33.1'
      )
      expect(resource.provider).to receive(:pkg) do |arg|
        expect(arg).to include('curl-7.33.1')
      end
      resource.provider.install
    end

    it "should call pkg with the specified package version" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'curl',
        :provider => :pkgng,
        :ensure   => '7.33.1'
      )
      expect(resource.provider).to receive(:pkg) do |arg|
        expect(arg).to include('curl-7.33.1')
      end
      resource.provider.install
    end

    it "should call pkg with the specified package repo" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'curl',
        :provider => :pkgng,
        :source   => 'urn:freebsd:repo:FreeBSD'
      )
      expect(resource.provider).to receive(:pkg) do |arg|
        expect(arg).to include('FreeBSD')
      end
      resource.provider.install
    end

    it "should call pkg with the specified install options string" do
      resource = Puppet::Type.type(:package).new(
        :name            => 'curl',
        :provider        => :pkgng,
        :install_options => ['--foo', '--bar']
      )
      expect(resource.provider).to receive(:pkg) do |arg|
        expect(arg).to include('--foo', '--bar')
      end
      resource.provider.install
    end

    it "should call pkg with the specified install options hash" do
      resource = Puppet::Type.type(:package).new(
        :name            => 'curl',
        :provider        => :pkgng,
        :install_options => ['--foo', { '--bar' => 'baz', '--baz' => 'foo' }]
      )
      expect(resource.provider).to receive(:pkg) do |arg|
        expect(arg).to include('--foo', '--bar=baz', '--baz=foo')
      end
      resource.provider.install
    end
  end

  context "#prefetch" do
    it "should fail gracefully when " do
      allow(described_class).to receive(:instances).and_return([])
      expect{ described_class.prefetch({}) }.to_not raise_error
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      pkg_query_zsh = File.read(my_fixture('pkg.query.zsh'))
      allow(described_class).to receive(:get_resource_info).with('zsh').and_return(pkg_query_zsh)
      described_class.prefetch({installed_name => installed_resource})
      expect(installed_provider.query).to be >= {:version=>'5.0.2_1'}
    end

    it "should return nil if not present" do
      allow(described_class).to receive(:get_resource_info).with('bash').and_raise(Puppet::ExecutionFailure, 'An error occurred')

      expect(provider.query).to equal(nil)
    end
  end

  describe "latest" do
    it "should retrieve the correct version of the latest package" do
      described_class.prefetch( { installed_name => installed_resource })
      expect(installed_provider.latest).not_to be_nil
    end

    it "should set latest to newer package version when available" do
      instances = described_class.instances
      curl = instances.find {|i| i.properties[:origin] == 'ftp/curl' }
      expect(curl.properties[:latest]).to eq('7.33.0_2')
    end

    it "should call update to upgrade the version" do
      allow(described_class).to receive(:get_resource_info).with('ftp/curl').and_return('curl 7.61.1 ftp/curl')

      resource = Puppet::Type.type(:package).new(
        :name     => 'ftp/curl',
        :provider => pkgng,
        :ensure   => :latest
      )

      expect(resource.provider).to receive(:update)

      resource.property(:ensure).sync
    end
  end

  describe "get_latest_version" do
    it "should rereturn nil when the current package is the latest" do
      version_list = File.read(my_fixture('pkg.version'))
      allow(described_class).to receive(:get_version_list).and_return(version_list)
      nmap_latest_version = described_class.get_latest_version('security/nmap')

      expect(nmap_latest_version).to be_nil
    end

    it "should match the package name exactly" do
      version_list = File.read(my_fixture('pkg.version'))
      allow(described_class).to receive(:get_version_list).and_return(version_list)
      bash_comp_latest_version = described_class.get_latest_version('shells/bash-completion')

      expect(bash_comp_latest_version).to eq('2.1_3')
    end

    it "should return nil when the package is orphaned" do
      version_list = File.read(my_fixture('pkg.version'))
      allow(described_class).to receive(:get_version_list).and_return(version_list)
      orphan_latest_version = described_class.get_latest_version('sysutils/orphan')
      expect(orphan_latest_version).to be_nil
    end

    it "should return nil when the package is broken" do
      version_list = File.read(my_fixture('pkg.version'))
      allow(described_class).to receive(:get_version_list).and_return(version_list)
      broken_latest_version = described_class.get_latest_version('sysutils/broken')
      expect(broken_latest_version).to be_nil
    end
  end

  describe "confine" do
    context "on FreeBSD" do
      it "should be the default provider" do
        expect(Facter).to receive(:value).with(:operatingsystem).at_least(:once).and_return(:freebsd)
        expect(described_class).to be_default
      end
    end
  end
end
