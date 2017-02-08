# -*- coding: utf-8 -*-

module Puppet
  class Type
    # Allow declaring that a type is actually a capability
    class << self
      attr_accessor :is_capability

      def is_capability?
        c = is_capability
        c.nil? ? false : c
      end
    end

    # Returns whether this type represents an application instance; since
    # only defined types, i.e., instances of Puppet::Resource::Type can
    # represent application instances, this implementation always returns
    # +false+. Having this method though makes code checking whether a
    # resource is an application instance simpler
    def self.application?
      false
    end
  end
end
