require 'puppet/util/feature'

if Puppet::Util::Platform.windows?
  Puppet.features.add(:eventlog)
end
