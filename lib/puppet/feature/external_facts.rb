require 'facter'

Puppet.features.add(:external_facts) {
  Facter.respond_to?(:search_external)
}
