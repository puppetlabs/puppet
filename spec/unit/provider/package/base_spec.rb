require 'spec_helper'
require 'puppet/provider/package'

describe Puppet::Provider::Package do
  it 'returns absent for uninstalled packages when not purgeable' do
    provider = Puppet::Provider::Package.new
    provider.expects(:query).returns nil
    provider.class.expects(:feature?).with(:purgeable).returns false
    expect(provider.properties[:ensure]).to eq(:absent)
  end

  it 'returns purged for uninstalled packages when purgeable' do
    provider = Puppet::Provider::Package.new
    provider.expects(:query).returns nil
    provider.class.expects(:feature?).with(:purgeable).returns true
    expect(provider.properties[:ensure]).to eq(:purged)
  end
end
