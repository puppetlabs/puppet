require 'puppet'

module Puppet::Facts

  # Replaces the facter implementation with cfacter if the cfacter feature is present.
  #
  # @return [Boolean] True if the facter implementation was replaced or false if the cfacter feature is not present.
  # @api public
  def self.replace_facter
    return false unless Puppet.features.cfacter?
    return true if Facter == CFacter

    # Sync search directories
    CFacter.search Facter.search_path
    CFacter.search_external Facter.search_external_path if Puppet.features.external_facts?

    # CFacter supports external facts
    Puppet.features.add(:external_facts) { true }

    # Alias Facter to CFacter
    Object.send(:remove_const, :Facter)
    Object.send(:const_set, :Facter, CFacter)
    true
  end

end
