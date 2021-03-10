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

  custom_environment = {"HOME"=>ENV["HOME"]}
  custom_environment['PKG_CONFIG_PATH'] = '/opt/puppetlabs/puppet/lib/pkgconfig'

  let(:execute_options) { {:failonfail => true, :combine => true, :custom_environment => custom_environment} }

  before :each do
    resource.provider = provider
    allow(described_class).to receive(:command).with(:gemcmd).and_return(provider_gem_cmd)
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
  end

  context "when installing" do
    before :each do
      allow(provider).to receive(:rubygem_version).and_return('1.9.9')
    end

    it "should use the path to the gem command" do
      allow(described_class).to receive(:validate_command).with(provider_gem_cmd)
      expect(described_class).to receive(:execute).with(be_a(Array), execute_options) { |args| expect(args[0]).to eq(provider_gem_cmd) }.and_return('')
      provider.install
    end

    it "should not append install_options by default" do
      expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{install --no-rdoc --no-ri myresource}).and_return('')
      provider.install
    end

    it "should allow setting an install_options parameter" do
      resource[:install_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{install --force --bindir=/usr/bin --no-rdoc --no-ri myresource}).and_return('')
      provider.install
    end
  end

  context "when uninstalling" do
    it "should use the path to the gem command" do
      allow(described_class).to receive(:validate_command).with(provider_gem_cmd)
      expect(described_class).to receive(:execute).with(be_a(Array), execute_options) { |args| expect(args[0]).to eq(provider_gem_cmd) }.and_return('')
      provider.uninstall
    end

    it "should not append uninstall_options by default" do
      expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{uninstall --executables --all myresource}).and_return('')
      provider.uninstall
    end

    it "should allow setting an uninstall_options parameter" do
      resource[:uninstall_options] = [ '--force', {'--bindir' => '/usr/bin' } ]
      expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{uninstall --executables --all myresource --force --bindir=/usr/bin}).and_return('')
      provider.uninstall
    end

    it 'should invalidate the rubygems cache' do
      gem_source = double('gem_source')
      allow(Puppet::Util::Autoload).to receive(:gem_source).and_return(gem_source)
      expect(described_class).to receive(:execute_gem_command).with(provider_gem_cmd, %w{uninstall --executables --all myresource}).and_return('')
      expect(gem_source).to receive(:clear_paths)
      provider.uninstall
    end
  end

  context 'calculated specificity' do
    context 'when is not defaultfor' do
      subject { described_class.specificity }
      it { is_expected.to eql 1 }
    end

    context 'when is defaultfor' do
      let(:os) {  Facter.value(:operatingsystem) }
      subject do
        described_class.defaultfor(operatingsystem: os)
        described_class.specificity
      end
      it { is_expected.to be > 100 }
    end
  end

end
