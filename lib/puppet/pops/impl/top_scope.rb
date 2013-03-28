require 'puppet/pops/api'

module Puppet::Pops::Impl
  class TopScope < BaseScope
    attr_reader :type_creator
    def initialize
      super
    end

    def is_top_scope?
      true
    end

    # Lazy initialization of type_creator
    # (Optimization for simple usage/tests)
    def type_creator
      @type_creator ||= ::Pops::Impl::TypeCreator.new
      @type_creator
    end
  end
end
