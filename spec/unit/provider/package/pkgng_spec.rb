#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/package/pkgng'

provider_class = Puppet::Type.type(:package).provider(:pkgng)

describe provider_class do
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
      #resource.expects(:err).never
      catalog.add_resource(resource)
    end
    catalog.apply
  end

  before do
    provider_class.stubs(:command).with(:pkg) { '/usr/local/sbin/pkg' }

    info = File.read(my_fixture('pkg.info'))
    provider_class.stubs(:get_query).returns(info)

    version_list = File.read(my_fixture('pkg.version'))
    provider_class.stubs(:get_version_list).returns(version_list)
  end

  context "#instances" do
    it "should return the empty set if no packages are listed" do
      provider_class.stubs(:get_query).returns('')
      provider_class.stubs(:get_version_list).returns('')
      expect(provider_class.instances).to be_empty
    end

    it "should return all packages when invoked" do
      expect(provider_class.instances.map(&:name).sort).to eq(
        %w{ca_root_nss curl nmap pkg gnupg zsh tac_plus}.sort)
    end

    it "should set latest to current version when no upgrade available" do
      nmap = provider_class.instances.find {|i| i.properties[:origin] == 'security/nmap' }

      expect(nmap.properties[:version]).to eq(nmap.properties[:latest])
    end

    it "should return an empty array when pkg calls raise an exception" do
      provider_class.stubs(:get_query).raises(Puppet::ExecutionFailure, 'An error occurred.')
      expect(provider_class.instances).to eq([])
    end

    describe "version" do
      it "should retrieve the correct version of the current package" do
        zsh = provider_class.instances.find {|i| i.properties[:origin] == 'shells/zsh' }
        expect( zsh.properties[:version]).to eq('5.0.2_1')
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
      resource.provider.expects(:pkg) do |arg|
        arg.should include('curl-7.33.1')
      end
      resource.provider.install
    end

    it "should call pkg with the specified package version" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'curl',
        :provider => :pkgng,
        :ensure   => '7.33.1'
      )
      resource.provider.expects(:pkg) do |arg|
        arg.should include('curl-7.33.1')
      end
      resource.provider.install
    end

    it "should call pkg with the specified package repo" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'curl',
        :provider => :pkgng,
        :source   => 'urn:freebsd:repo:FreeBSD'
      )
      resource.provider.expects(:pkg) do |arg|
        arg.should include('FreeBSD')
      end
      resource.provider.install
    end
  end

  context "#prefetch" do
    it "should fail gracefully when " do
      provider_class.stubs(:instances).returns([])
      expect{ provider_class.prefetch({}) }.to_not raise_error
    end
  end

  context "#query" do
    it "should return the installed version if present" do
      provider_class.prefetch({installed_name => installed_resource})
      expect(installed_provider.query).to eq({:version=>'5.0.2_1'})
    end

    it "should return nil if not present" do
      fixture = File.read(my_fixture('pkg.query_absent'))
      provider_class.stubs(:get_resource_info).with('bash').returns(fixture)
      expect(provider.query).to equal(nil)
    end
  end

  describe "latest" do
    it "should retrieve the correct version of the latest package" do
      provider_class.prefetch( { installed_name => installed_resource })
      expect(installed_provider.latest).not_to be_nil
    end

    it "should set latest to newer package version when available" do
      instances = provider_class.instances
      curl = instances.find {|i| i.properties[:origin] == 'ftp/curl' }
      expect(curl.properties[:latest]).to eq('7.33.0_2')
    end

    it "should call update to upgrade the version" do
      resource = Puppet::Type.type(:package).new(
        :name     => 'ftp/curl',
        :provider => pkgng,
        :ensure   => :latest
      )

      resource.provider.expects(:update)

      resource.property(:ensure).sync
    end
  end

  describe "get_latest_version" do
    it "should rereturn nil when the current package is the latest" do
      version_list = File.read(my_fixture('pkg.version'))
      nmap_latest_version = provider_class.get_latest_version('security/nmap', version_list)
      expect(nmap_latest_version).to be_nil
    end

    it "should match the package name exactly" do
      version_list = File.read(my_fixture('pkg.version'))
      bash_comp_latest_version = provider_class.get_latest_version('shells/bash-completion', version_list)
      expect(bash_comp_latest_version).to eq('2.1_3')
    end
  end

  describe "confine" do
    context "on FreeBSD" do
      it "should be the default provider" do
        Facter.expects(:value).with(:operatingsystem).at_least_once.returns :freebsd
        expect(provider_class).to be_default
      end
    end
  end
end
