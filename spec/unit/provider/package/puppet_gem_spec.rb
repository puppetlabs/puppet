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
    let(:puppet_gem) { 'gem.bat' }
  else
    let(:puppet_gem) { '/opt/puppetlabs/puppet/bin/gem' }
  end

  before :each do
    resource.provider = provider
  end

  context "when installing" do
    it "should use the path to the puppet gem" do
      described_class.stubs(:command).with(:gemcmd).returns puppet_gem
      described_class.stubs(:validate_package_command).returns puppet_gem
      provider.expects(:execute).with { |args| args[0] == puppet_gem }.returns ''
      provider.install
    end
  end
end
