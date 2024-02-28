# frozen_string_literal: true

require_relative '../../puppet/util/feature'

Puppet.features.add(:ssh, :libs => %(net/ssh))
