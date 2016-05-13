#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package), "when choosing a default package provider" do
  before do
    # the default provider is cached.
    Puppet::Type.type(:package).defaultprovider = nil
  end

  def provider_name(os)
    case os
    when 'Solaris'
      if Puppet::Util::Package.versioncmp(Facter.value(:kernelrelease), '5.11') >= 0
        :pkg
      else
        :sun
      end
    when 'Ubuntu'
      :apt
    when 'Debian'
      :apt
    when 'Darwin'
      :pkgdmg
    when 'RedHat'
      if ['2.1', '3', '4'].include?(Facter.value(:lsbdistrelease))
        :up2date
      else
        :yum
      end
    when 'Fedora'
      if Puppet::Util::Package.versioncmp(Facter.value(:operatingsystemmajrelease), '22') >= 0
        :dnf
      else
        :yum
      end
    when 'FreeBSD'
      :ports
    when 'OpenBSD'
      :openbsd
    when 'DragonFly'
      :pkgin
    when 'OpenWrt'
      :opkg
    end
  end

  it "should have a default provider" do
    expect(Puppet::Type.type(:package).defaultprovider).not_to be_nil
  end

  it "should choose the correct provider each platform" do
    unless default_provider = provider_name(Facter.value(:operatingsystem))
      pending("No default provider specified in this test for #{Facter.value(:operatingsystem)}")
    end
    expect(Puppet::Type.type(:package).defaultprovider.name).to eq(default_provider)
  end
end

describe Puppet::Type.type(:package), "when packages with the same name are sourced" do
  before :each do
    Process.stubs(:euid).returns 0
    @provider = stub(
      'provider',
      :class           => Puppet::Type.type(:package).defaultprovider,
      :clear           => nil,
      :satisfies?      => true,
      :name            => :mock,
      :validate_source => nil
    )
    Puppet::Type.type(:package).defaultprovider.stubs(:new).returns(@provider)
    Puppet::Type.type(:package).defaultprovider.stubs(:instances).returns([])
    @package = Puppet::Type.type(:package).new(:name => "yay", :ensure => :present)

    @catalog = Puppet::Resource::Catalog.new
    @catalog.add_resource(@package)
  end

  describe "with same title" do
    before {
      @alt_package = Puppet::Type.type(:package).new(:name => "yay", :ensure => :present)
    }
    it "should give an error" do
      expect {
        @catalog.add_resource(@alt_package)
      }.to raise_error Puppet::Resource::Catalog::DuplicateResourceError, 'Duplicate declaration: Package[yay] is already declared; cannot redeclare'
    end
  end

  describe "with different title" do
    before :each do
      @alt_package = Puppet::Type.type(:package).new(:name => "yay", :title => "gem-yay", :ensure => :present)
    end

    it "should give an error" do
      provider_name = Puppet::Type.type(:package).defaultprovider.name
      expect {
        @catalog.add_resource(@alt_package)
      }.to raise_error ArgumentError, "Cannot alias Package[gem-yay] to [\"yay\", :#{provider_name}]; resource [\"Package\", \"yay\", :#{provider_name}] already declared"
    end
  end

  describe "from multiple providers" do
    provider_class = Puppet::Type.type(:package).provider(:gem)

    before :each do
      @alt_provider = provider_class.new
      @alt_package = Puppet::Type.type(:package).new(:name => "yay", :title => "gem-yay", :provider => @alt_provider, :ensure => :present)
      @catalog.add_resource(@alt_package)
    end

    describe "when it should be present" do
      [:present, :latest, "1.0"].each do |state|
        it "should do nothing if it is #{state.to_s}" do
          @provider.expects(:properties).returns(:ensure => state).at_least_once
          @alt_provider.expects(:properties).returns(:ensure => state).at_least_once
          @catalog.apply
        end
      end

      [:purged, :absent].each do |state|
        it "should install if it is #{state.to_s}" do
          @provider.stubs(:properties).returns(:ensure => state)
          @provider.expects(:install)
          @alt_provider.stubs(:properties).returns(:ensure => state)
          @alt_provider.expects(:install)
          @catalog.apply
        end
      end
    end
  end
end

describe Puppet::Type.type(:package), 'logging package state transitions' do

  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:provider) { stub('provider', :class => Puppet::Type.type(:package).defaultprovider, :clear => nil, :validate_source => nil) }

  before :each do
    Process.stubs(:euid).returns 0
    provider.stubs(:satisfies?).with([:purgeable]).returns(true)
    provider.class.stubs(:instances).returns([])
    provider.stubs(:install).returns nil
    provider.stubs(:uninstall).returns nil
    provider.stubs(:purge).returns nil
    Puppet::Type.type(:package).defaultprovider.stubs(:new).returns(provider)
  end

  after :each do
    Puppet::Type.type(:package).defaultprovider = nil
  end

  # Map of old state -> {new state -> change}
  states = {
    # 'installed' transitions to 'removed' or 'purged'
    :installed => {
      :installed => nil,
      :absent    => 'removed',
      :purged    => 'purged'
    },
    # 'absent' transitions to 'created' or 'purged'
    :absent => {
      :installed => 'created',
      :absent    => nil,
      :purged    => 'purged'
    },
    # 'purged' transitions to 'created'
    :purged => {
      :installed => 'created',
      :absent    => nil,
      :purged    => nil
    }
  }

  states.each do |old, new_states|
    describe "#{old} package" do

      before :each do
        provider.stubs(:properties).returns(:ensure => old)
      end

      new_states.each do |new, status|
        it "ensure => #{new} should log #{status ? status : 'nothing'}" do
          catalog.add_resource(described_class.new(:name => 'yay', :ensure => new))
          catalog.apply

          logs = catalog.apply.report.logs
          if status
            expect(logs.first.source).to eq("/Package[yay]/ensure")
            expect(logs.first.message).to eq(status)
          else
            expect(logs.first).to be_nil
          end
        end
      end
    end
  end
end

