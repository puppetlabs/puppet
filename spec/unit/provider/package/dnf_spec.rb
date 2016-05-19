require 'spec_helper'

# Note that much of the functionality of the dnf provider is already tested with yum provider tests,
# as yum is the parent provider.

provider_class = Puppet::Type.type(:package).provider(:dnf)

describe provider_class do
  it_behaves_like 'RHEL package provider', provider_class, 'dnf'
end
