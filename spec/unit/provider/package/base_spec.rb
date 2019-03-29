require 'spec_helper'
require 'puppet/provider/package'

describe Puppet::Provider::Package do
  it 'returns absent for uninstalled packages when not purgeable' do
    provider = Puppet::Provider::Package.new
    expect(provider).to receive(:query).and_return(nil)
    expect(provider.class).to receive(:feature?).with(:purgeable).and_return(false)
    expect(provider.properties[:ensure]).to eq(:absent)
  end

  it 'returns purged for uninstalled packages when purgeable' do
    provider = Puppet::Provider::Package.new
    expect(provider).to receive(:query).and_return(nil)
    expect(provider.class).to receive(:feature?).with(:purgeable).and_return(true)
    expect(provider.properties[:ensure]).to eq(:purged)
  end
end
