# frozen_string_literal: true

require_relative '../../puppet/util/feature'

# Is the pe license library installed providing the ability to read licenses.
Puppet.features.add(:pe_license, :libs => %(pe_license))
