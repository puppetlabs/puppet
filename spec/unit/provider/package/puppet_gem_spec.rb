require 'spec_helper'

describe Puppet::Type.type(:package).provider(:puppet_gem) do
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => 'myresource',
      :ensure   => :installed
    )
  end

  let(:provider) do
    provider = described_class.new
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

  context "when installing" do
    it "should use the path to the gem" do
      expect(described_class).to receive(:which).with(puppet_gem).and_return(puppet_gem)
      expect(provider).to receive(:execute) do |args|
        expect(args[0]).to eq(puppet_gem)
        ''
      end
      provider.install
    end

    it "should not append install_options by default" do
      expect(provider).to receive(:execute) do |args|
        expect(args.length).to eq(5)
        ''
      end
      provider.install
    end

    it "should allow setting an install_options parameter" do
      resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(provider).to receive(:execute) do |args|
        expect(args[2]).to eq('--force')
        expect(args[3]).to eq('--bindir=/usr/bin')
        ''
      end
      provider.install
    end
  end

  context "when uninstalling" do
    it "should use the path to the gem" do
      expect(described_class).to receive(:which).with(puppet_gem).and_return(puppet_gem)
      expect(provider).to receive(:execute) do |args|
        expect(args[0]).to eq(puppet_gem)
        ''
      end
      provider.install
    end

    it "should not append uninstall_options by default" do
      expect(provider).to receive(:execute) do |args|
        expect(args.length).to eq(5)
        ''
      end
      provider.uninstall
    end

    it "should allow setting an uninstall_options parameter" do
      resource[:uninstall_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(provider).to receive(:execute) do |args|
        expect(args[5]).to eq('--force')
        expect(args[6]).to eq('--bindir=/usr/bin')
        ''
      end
      provider.uninstall
    end
  end
end
