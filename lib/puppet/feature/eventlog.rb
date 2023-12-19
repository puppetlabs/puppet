# frozen_string_literal: true

require_relative '../../puppet/util/feature'

if Puppet::Util::Platform.windows?
  Puppet.features.add(:eventlog)
end
