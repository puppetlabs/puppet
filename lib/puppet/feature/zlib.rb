# frozen_string_literal: true

require_relative '../../puppet/util/feature'

# We want this to load if possible, but it's not automatically
# required.
Puppet.features.add(:zlib, :libs => %(zlib))
