# frozen_string_literal: true

require_relative '../../puppet/util/feature'

Puppet.features.add(:msgpack, :libs => ["msgpack"])
