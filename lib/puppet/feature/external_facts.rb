require 'facter/util/config'

Puppet.features.add(:external_facts) {
   Facter::Util::Config.respond_to?(:external_facts_dirs=)
}
