require 'spec_helper'

# Note that much of the functionality of the tdnf provider is already tested with yum provider tests,
# as yum is the parent provider, via dnf
describe Puppet::Type.type(:package).provider(:tdnf) do
  it_behaves_like 'RHEL package provider', described_class, 'tdnf'

  context 'default' do
    it 'should be the default provider on PhotonOS' do
      Facter.stubs(:value).with(:osfamily).returns(:redhat)
      Facter.stubs(:value).with(:operatingsystem).returns("PhotonOS")
      expect(described_class).to be_default
    end
  end
end
