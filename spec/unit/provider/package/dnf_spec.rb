require 'spec_helper'

# Note that much of the functionality of the dnf provider is already tested with yum provider tests,
# as yum is the parent provider.

provider_class = Puppet::Type.type(:package).provider(:dnf)

context 'default' do
  (19..21).each do |ver|
    it "should not be the default provider on fedora#{ver}" do
      File.stubs(:file?).with('/usr/bin/dnf').returns(false)
      expect(provider_class).to_not be_default
    end
  end

  (22..26).each do |ver|
    it "should be the default provider on fedora#{ver}" do
      File.stubs(:file?).with('/usr/bin/dnf').returns(true)
      expect(provider_class).to be_default
    end
  end
end

describe provider_class do
  it_behaves_like 'RHEL package provider', provider_class, 'dnf'
end
