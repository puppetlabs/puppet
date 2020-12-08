require_relative '../../puppet/util/feature'

Puppet.features.add(:ssh, :libs => %{net/ssh})
