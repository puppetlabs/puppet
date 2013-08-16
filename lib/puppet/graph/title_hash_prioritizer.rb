# Prioritize keys, which must be Puppet::Resources, based on a static hash of
# the key's ref. This prioritizer does not take containment into account.
#
# @api private
require 'digest/sha1'

class Puppet::Graph::TitleHashPrioritizer < Puppet::Graph::Prioritizer
  def generate_priority_for(resource)
    record_priority_for(resource,
                        Digest::SHA1.hexdigest("NaCl, MgSO4 (salts) and then #{resource.ref}"))
  end

  def generate_priority_contained_in(container, resource)
    generate_priority_for(resource)
  end
end
