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

  if Puppet::Util::Platform.windows?
    let(:provider_gem_cmd) { 'C:\Program Files\Puppet Labs\Puppet\puppet\bin\gem.bat' }
  else
    let(:provider_gem_cmd) { '/opt/puppetlabs/puppet/bin/gem' }
  end

  let(:execute_options) do
    {
      failonfail: true,
      combine: true,
      custom_environment: {
        'HOME'=>ENV['HOME'],
        'PKG_CONFIG_PATH' => '/opt/puppetlabs/puppet/lib/pkgconfig'
      }
    }
  end

  before :each do
    resource.provider = provider
    if Puppet::Util::Platform.windows?
      # provider is loaded before we can stub, so stub the class we're testing
      allow(provider.class).to receive(:command).with(:gemcmd).and_return(provider_gem_cmd)
    else
      allow(provider.class).to receive(:which).with(provider_gem_cmd).and_return(provider_gem_cmd)
    end
    allow(File).to receive(:file?).with(provider_gem_cmd).and_return(true)
  end

  context "when installing" do
    before :each do
      allow(provider).to receive(:rubygem_version).and_return('1.9.9')
    end

    it "should use the path to the gem command" do
      expect(described_class).to receive(:execute).with([provider_gem_cmd, be_an(Array)], be_a(Hash)).and_return('')
      provider.install
    end

    it "should not append install_options by default" do
      expect(described_class).to receive(:execute).with([provider_gem_cmd, %w{install --no-rdoc --no-ri myresource}], anything).and_return('')
      provider.install
    end

    it "should allow setting an install_options parameter" do
      resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(described_class).to receive(:execute).with([provider_gem_cmd, %w{install --force --bindir=/usr/bin --no-rdoc --no-ri myresource}], anything).and_return('')
      provider.install
    end
  end

  context "when uninstalling" do
    it "should use the path to the gem command" do
      expect(described_class).to receive(:execute).with([provider_gem_cmd, be_an(Array)], be_a(Hash)).and_return('')
      provider.uninstall
    end

    it "should not append uninstall_options by default" do
      expect(described_class).to receive(:execute).with([provider_gem_cmd, %w{uninstall --executables --all myresource}], anything).and_return('')
      provider.uninstall
    end

    it "should allow setting an uninstall_options parameter" do
      resource[:uninstall_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(described_class).to receive(:execute).with([provider_gem_cmd, %w{uninstall --executables --all myresource --force --bindir=/usr/bin}], anything).and_return('')
      provider.uninstall
    end

    it 'should invalidate the rubygems cache' do
      gem_source = double('gem_source')
      allow(Puppet::Util::Autoload).to receive(:gem_source).and_return(gem_source)
      expect(described_class).to receive(:execute).with([provider_gem_cmd, %w{uninstall --executables --all myresource}], anything).and_return('')
      expect(gem_source).to receive(:clear_paths)
      provider.uninstall
    end
  end

  context 'calculated specificity' do
    include_context 'provider specificity'

    context 'when is not defaultfor' do
      subject { described_class.specificity }
      it { is_expected.to eql 1 }
    end

    context 'when is defaultfor' do
      let(:os) { Puppet.runtime[:facter].value('os.name') }
      subject do
        described_class.defaultfor('os.name': os)
        described_class.specificity
      end
      it { is_expected.to be > 100 }
    end
  end
end
