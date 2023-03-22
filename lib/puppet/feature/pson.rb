require_relative '../../puppet/util/feature'

# PSON is deprecated, use JSON instead
Puppet.features.add(:pson, :libs => ['puppet/external/pson'])
