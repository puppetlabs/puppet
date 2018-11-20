require 'spec_helper'

# Note that much of the functionality of the dnf provider is already tested with yum provider tests,
# as yum is the parent provider.

describe Puppet::Type.type(:package).provider(:dnf) do
  context 'default' do
    (19..21).each do |ver|
      it "should not be the default provider on fedora#{ver}" do
        Facter.stubs(:value).with(:osfamily).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystem).returns(:fedora)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
        expect(described_class).to_not be_default
      end
    end

    (22..26).each do |ver|
      it "should be the default provider on fedora#{ver}" do
        Facter.stubs(:value).with(:osfamily).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystem).returns(:fedora)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns("#{ver}")
        expect(described_class).to be_default
      end
    end

    it "should not be the default provider on rhel7" do
        Facter.stubs(:value).with(:osfamily).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystem).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns("7")
        expect(described_class).to_not be_default
    end

    it "should be the default provider on rhel8" do
        Facter.stubs(:value).with(:osfamily).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystem).returns(:redhat)
        Facter.stubs(:value).with(:operatingsystemmajrelease).returns("8")
        expect(described_class).to be_default
    end

  end

  it_behaves_like 'RHEL package provider', described_class, 'dnf'
end
