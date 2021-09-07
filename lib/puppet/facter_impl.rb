# frozen_string_literal: true

#
# @api private
# Default Facter implementation that delegates to Facter API
#

module Puppet
  class FacterImpl
    def initialize
      require 'facter'
    end

    def value(fact_name)
      ::Facter.value(fact_name)
    end

    def add(name, &block)
      ::Facter.add(name, &block)
    end
  end
end
