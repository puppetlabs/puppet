require 'puppet/util/feature'

Puppet.features.rubygems?
Puppet.features.add(:ssh, :libs => %{net/ssh})
