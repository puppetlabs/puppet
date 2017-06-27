#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:puppet_gem)

describe provider_class do
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => 'myresource',
      :ensure   => :installed
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  if Puppet.features.microsoft_windows?
    let(:puppet_gem) { 'gem' }
  else
    let(:puppet_gem) { '/opt/puppetlabs/puppet/bin/gem' }
  end

  before :each do
    resource.provider = provider
  end

  describe "when installing" do
    it "should use the path to the gem" do
      provider_class.expects(:which).with(puppet_gem).returns(puppet_gem)
      provider.expects(:execute).with { |args| args[0] == puppet_gem }.returns ''
      provider.install
    end

    it "should not append install_options by default" do
      provider.expects(:execute).with { |args| args.length == 5 }.returns ''
      provider.install
    end

    it "should allow setting an install_options parameter" do
      resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      provider.expects(:execute).with { |args| args[2] == '--force' && args[3] == '--bindir=/usr/bin' }.returns ''
      provider.install
    end
  end

  describe "when uninstalling" do
    it "should use the path to the gem" do
      provider_class.expects(:which).with(puppet_gem).returns(puppet_gem)
      provider.expects(:execute).with { |args| args[0] == puppet_gem }.returns ''
      provider.install
    end

    it "should not append uninstall_options by default" do
      provider.expects(:execute).with { |args| args.length == 5 }.returns ''
      provider.uninstall
    end

    it "should allow setting an uninstall_options parameter" do
      resource[:uninstall_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      provider.expects(:execute).with { |args| args[5] == '--force' && args[6] == '--bindir=/usr/bin' }.returns ''
      provider.uninstall
    end
  end
end
