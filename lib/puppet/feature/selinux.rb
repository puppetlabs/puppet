require_relative '../../puppet/util/feature'

Puppet.features.add(:selinux, :libs => ["selinux"])
