# frozen_string_literal: true

require_relative '../../puppet/util/feature'

Puppet.features.add(:hiera_eyaml, :libs => ['hiera/backend/eyaml/parser/parser'])
