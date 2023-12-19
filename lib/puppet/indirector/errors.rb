# frozen_string_literal: true

require_relative '../../puppet/error'

module Puppet::Indirector
  class ValidationError < Puppet::Error; end
end
