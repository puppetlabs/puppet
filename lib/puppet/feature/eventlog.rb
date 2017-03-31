require 'puppet/util/feature'

if Puppet.features.microsoft_windows?
  Puppet.features.add(:eventlog)
end
