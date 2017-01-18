require 'puppet/util/feature'

Puppet.features.add(:hiera_eyaml, :libs => ['hiera/backend/eyaml/parser/parser'])
