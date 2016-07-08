require 'facter'

Puppet.features.add(:external_facts) {
  true
}
