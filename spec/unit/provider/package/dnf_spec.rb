require 'spec_helper'

# Note that much of the functionality of the dnf provider is already tested with yum provider tests,
# as yum is the parent provider.
describe Puppet::Type.type(:package).provider(:dnf) do
  context 'default' do
    (19..21).each do |ver|
      it "should not be the default provider on fedora#{ver}" do
        allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
        allow(Facter).to receive(:value).with('os.name').and_return(:fedora)
        allow(Facter).to receive(:value).with('os.release.major').and_return("#{ver}")
        expect(described_class).to_not be_default
      end
    end

    (22..26).each do |ver|
      it "should be the default provider on fedora#{ver}" do
        allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
        allow(Facter).to receive(:value).with('os.name').and_return(:fedora)
        allow(Facter).to receive(:value).with('os.release.major').and_return("#{ver}")
        expect(described_class).to be_default
      end
    end

    it "should not be the default provider on rhel7" do
      allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.name').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.release.major').and_return("7")
      expect(described_class).to_not be_default
    end

    it "should be the default provider on some random future fedora" do
      allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.name').and_return(:fedora)
      allow(Facter).to receive(:value).with('os.release.major').and_return("8675")
      expect(described_class).to be_default
    end

    it "should be the default provider on rhel8" do
      allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.name').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.release.major').and_return("8")
      expect(described_class).to be_default
    end

    it "should be the default provider on Amazon Linux 2023" do
      allow(Facter).to receive(:value).with('os.family').and_return(:redhat)
      allow(Facter).to receive(:value).with('os.name').and_return(:amazon)
      allow(Facter).to receive(:value).with('os.release.major').and_return("2023")
      expect(described_class).to be_default
    end
  end

  describe 'provider features' do
    it { is_expected.to be_versionable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_virtual_packages }
    it { is_expected.to be_install_only }
  end

  it_behaves_like 'RHEL package provider', described_class, 'dnf'
end
