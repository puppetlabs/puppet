require 'spec_helper'

describe Puppet::Type.type(:package).provider(:puppetserver_gem) do
  let(:resource) do
    Puppet::Type.type(:package).new(
      name: 'myresource',
      ensure: :installed
    )
  end

  let(:provider) do
    provider = described_class.new
    provider.resource = resource
    provider
  end

  let(:provider_gem_cmd) { '/opt/puppetlabs/bin/puppetserver' }

  let(:execute_options) do
    { failonfail: true, combine: true, custom_environment: { 'HOME' => ENV['HOME'] } }
  end

  before :each do
    resource.provider = provider
    allow(Puppet::Util).to receive(:which).with(provider_gem_cmd).and_return(provider_gem_cmd)
    allow(File).to receive(:file?).with(provider_gem_cmd).and_return(true)
  end

  describe "#install" do
    it "uses the path to the gem command" do
      expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, be_an(Array)], be_a(Hash)).and_return('')
      provider.install
    end

    it "appends version if given" do
      resource[:ensure] = ['1.2.1']
      expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install -v 1.2.1 --no-document myresource}], anything).and_return('')
      provider.install
    end

    context "with install_options" do
      it "does not append the parameter by default" do
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install --no-document myresource}], anything).and_return('')
        provider.install
      end

      it "allows setting the parameter" do
        resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install --force --bindir=/usr/bin --no-document myresource}], anything).and_return('')
        provider.install
      end
    end

    context "with source" do
      it "correctly sets http source" do
        resource[:source] = 'http://rubygems.com'
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install --no-document --source http://rubygems.com myresource}], anything).and_return('')
        provider.install
      end

      it "correctly sets local file source" do
        resource[:source] = 'paint-2.2.0.gem'
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install --no-document paint-2.2.0.gem}], anything).and_return('')
        provider.install
      end

      it "correctly sets local file source with URI scheme" do
        resource[:source] = 'file:///root/paint-2.2.0.gem'
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem install --no-document /root/paint-2.2.0.gem}], anything).and_return('')
        provider.install
      end

      it "raises if given a puppet URI scheme" do
        resource[:source] = 'puppet:///paint-2.2.0.gem'
        expect { provider.install }.to raise_error(Puppet::Error, 'puppet:// URLs are not supported as gem sources')
      end

      it "raises if given an invalid URI" do
        resource[:source] = 'h;ttp://rubygems.com'
        expect { provider.install }.to raise_error(Puppet::Error, /Invalid source '': bad URI\(is not URI\?\)/)
      end
    end
  end

  describe "#uninstall" do
    it "uses the path to the gem command" do
      expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, be_an(Array)], be_a(Hash)).and_return('')
      provider.uninstall
    end

    context "with uninstall_options" do
      it "does not append the parameter by default" do
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem uninstall --executables --all myresource}], anything).and_return('')
        provider.uninstall
      end

      it "allows setting the parameter" do
        resource[:uninstall_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
        expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem uninstall --executables --all myresource --force --bindir=/usr/bin}], anything).and_return('')
        provider.uninstall
      end
    end
  end

  describe ".gemlist" do
    context "listing installed packages" do
      it "uses the puppet_gem provider_command to list local gems" do
        allow(Puppet::Type::Package::ProviderPuppet_gem).to receive(:provider_command).and_return('/opt/puppetlabs/puppet/bin/gem')
        allow(described_class).to receive(:validate_command).with('/opt/puppetlabs/puppet/bin/gem')

        expected = { name: 'world_airports', provider: :puppetserver_gem, ensure: ['1.1.3'] }
        expect(Puppet::Util::Execution).to receive(:execute).with(['/opt/puppetlabs/puppet/bin/gem', %w[list --local]], anything).and_return(File.read(my_fixture('gem-list-local-packages')))
        expect(described_class.gemlist({ local: true })).to include(expected)
      end
    end

    it "appends the gem source if given" do
      expect(Puppet::Util::Execution).to receive(:execute).with([provider_gem_cmd, %w{gem list --remote --source https://rubygems.com}], anything).and_return('')
      described_class.gemlist({ source: 'https://rubygems.com' })
    end
  end

  context 'calculated specificity' do
    include_context 'provider specificity'

    context 'when is not defaultfor' do
      subject { described_class.specificity }
      it { is_expected.to eql 1 }
    end

    context 'when is defaultfor' do
      let(:os) {  Puppet.runtime[:facter].value('os.name') }
      subject do
        described_class.defaultfor('os.name': os)
        described_class.specificity
      end
      it { is_expected.to be > 100 }
    end
  end

end
