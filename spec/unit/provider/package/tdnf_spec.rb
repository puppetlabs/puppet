require 'spec_helper'

# Note that much of the functionality of the tdnf provider is already tested with yum provider tests,
# as yum is the parent provider, via dnf

provider_class = Puppet::Type.type(:package).provider(:tdnf)

context 'default' do
  it 'should be the default provider on PhotonOS' do
    Facter.stubs(:value).with(:osfamily).returns(:redhat)
    Facter.stubs(:value).with(:operatingsystem).returns("PhotonOS")
    expect(provider_class).to be_default
  end
end

describe provider_class do
  it_behaves_like 'RHEL package provider', provider_class, 'tdnf'
end
