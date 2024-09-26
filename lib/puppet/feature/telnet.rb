# frozen_string_literal: true

require_relative '../../puppet/util/feature'

Puppet.features.add(:telnet, :libs => %(net/telnet))
