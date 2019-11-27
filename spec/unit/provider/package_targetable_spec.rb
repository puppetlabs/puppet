require 'spec_helper'
require 'puppet'
require 'puppet/provider/package_targetable'
require 'puppet/provider/package/gem'

describe Puppet::Provider::Package::Targetable do
  let(:provider) { Puppet::Type.type(:package).provider(:gem) }
  let(:command)  { '/opt/bin/gem' }

  describe "when prefetching" do
    context "with a package without a command attribute" do
      let(:resource) { Puppet::Type.type(:package).new(:name => 'noo', :provider => 'gem', :ensure => :present) }
      let(:catalog)  { Puppet::Resource::Catalog.new }
      let(:instance) { provider.new(resource) }
      let(:packages) { { 'noo' => resource } }

      it "should pass a command to the instances method of the provider" do
        catalog.add_resource(resource)
        expect(provider).to receive(:instances).with(nil).and_return([instance])
        expect(provider.prefetch(packages)).to eq([nil]) # prefetch arbitrarily returns the array of commands for a provider in the catalog
      end
    end

    context "with a package with a command attribute" do
      let(:resource) { Puppet::Type.type(:package).new(:name => 'noo', :provider => 'gem', :ensure => :present) }
      let(:resource_targeted) { Puppet::Type.type(:package).new(:name => 'yes', :provider => 'gem', :command => command, :ensure => :present) }
      let(:catalog)  { Puppet::Resource::Catalog.new }
      let(:instance) { provider.new(resource) }
      let(:instance_targeted) { provider.new(resource_targeted) }
      let(:packages) { { 'noo' => resource, 'yes' => resource_targeted } }

      it "should pass the command to the instances method of the provider" do
        catalog.add_resource(resource)
        catalog.add_resource(resource_targeted)
        expect(provider).to receive(:instances).with(nil).and_return([instance])
        expect(provider).to receive(:instances).with(command).and_return([instance_targeted]).once
        expect(provider.prefetch(packages)).to eq([nil, command]) # prefetch arbitrarily returns the array of commands for a provider in the catalog
      end
    end
  end

  describe "when validating a command" do
    context "with no command" do
      it "report not functional" do
        expect { provider.validate_command(nil) }.to raise_error(Puppet::Error, "Provider gem package command is not functional on this host")
      end
    end
    context "with a missing command" do
      it "report does not exist" do
        expect { provider.validate_command(command) }.to raise_error(Puppet::Error, "Provider gem package command '#{command}' does not exist on this host")
      end
    end
    context "with an existing command" do
      it "validates" do
        allow(File).to receive(:file?).with(command).and_return(true)
        expect { provider.validate_command(command) }.not_to raise_error
      end
    end
  end
end
