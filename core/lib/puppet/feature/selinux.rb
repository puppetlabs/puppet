require 'puppet/util/feature'

Puppet.features.add(:selinux, :libs => ["selinux"])
