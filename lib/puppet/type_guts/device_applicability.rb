
module Puppet
  class Type
    # @comment These `apply_to` methods are horrible.  They should really be implemented
    #   as part of the usual system of constraints that apply to a type and
    #   provider pair, but were implemented as a separate shadow system.
    #
    # @comment We should rip them out in favour of a real constraint pattern around the
    #   target device - whatever that looks like - and not have this additional
    #   magic here. --daniel 2012-03-08
    #
    # Makes this type applicable to `:device`.
    # @return [Symbol] Returns `:device`
    # @api private
    #
    def self.apply_to_device
      @apply_to = :device
    end

    # Makes this type applicable to `:host`.
    # @return [Symbol] Returns `:host`
    # @api private
    #
    def self.apply_to_host
      @apply_to = :host
    end

    # Makes this type applicable to `:both` (i.e. `:host` and `:device`).
    # @return [Symbol] Returns `:both`
    # @api private
    #
    def self.apply_to_all
      @apply_to = :both
    end

    # Makes this type apply to `:host` if not already applied to something else.
    # @return [Symbol] a `:device`, `:host`, or `:both` enumeration
    # @api private
    def self.apply_to
      @apply_to ||= :host
    end

    # Returns true if this type is applicable to the given target.
    # @param target [Symbol] should be :device, :host or :target, if anything else, :host is enforced
    # @return [Boolean] true
    # @api private
    #
    def self.can_apply_to(target)
      [ target == :device ? :device : :host, :both ].include?(apply_to)
    end

    # @return [Boolean] Returns whether the resource is applicable to `:device`
    # Returns true if a resource of this type can be evaluated on a 'network device' kind
    # of hosts.
    # @api private
    def appliable_to_device?
      self.class.can_apply_to(:device)
    end

    # @return [Boolean] Returns whether the resource is applicable to `:host`
    # Returns true if a resource of this type can be evaluated on a regular generalized computer (ie not an appliance like a network device)
    # @api private
    def appliable_to_host?
      self.class.can_apply_to(:host)
    end
  end
end