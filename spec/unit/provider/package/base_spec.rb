require 'spec_helper'
require 'puppet/provider/package'

Puppet::Type.type(:package).provide(:test_base_provider, parent: Puppet::Provider::Package) do
  def query; end
end

describe Puppet::Provider::Package do
  let(:provider) {  Puppet::Type.type(:package).provider(:test_base_provider).new }

  it 'returns absent for uninstalled packages when not purgeable' do
    expect(provider.properties[:ensure]).to eq(:absent)
  end

  it 'returns purged for uninstalled packages when purgeable' do
    expect(provider.class).to receive(:feature?).with(:purgeable).and_return(true)
    expect(provider.properties[:ensure]).to eq(:purged)
  end
end
