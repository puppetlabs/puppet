require 'facter'
require 'puppet/util/feature'

Puppet.features.add :cfacter do
  begin
    require 'cfacter'

    # The first release of cfacter didn't have the necessary interface to work with Puppet
    # Therefore, if the version is 0.1.0, treat the feature as not present
    CFacter.version != '0.1.0'
  rescue LoadError
    false
  end
end
