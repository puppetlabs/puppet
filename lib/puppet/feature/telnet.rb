# frozen_string_literal: true

require_relative '../../puppet/util/feature'

Puppet.features.add :telnet do
  require 'net/telnet'
rescue LoadError
  false
end
