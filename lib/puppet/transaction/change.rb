require 'puppet/transaction'
require 'puppet/transaction/event'

# Handle all of the work around performing an actual change,
# including calling 'sync' on the properties and producing events.
class Puppet::Transaction::Change
    attr_accessor :is, :should, :property, :proxy

    # Switch the goals of the property, thus running the change in reverse.
    def backward
        @is, @should = @should, @is
        @property.should = @should

        @property.info "Reversing %s" % self
        return self.go
    end

    # Create our event object.
    def event
        result = property.event
        result.previous_value = is
        result.desired_value = should
        result
    end

    def initialize(property, currentvalue)
        @property = property
        @is = currentvalue

        @should = property.should

        @changed = false
    end

    # Perform the actual change.  This method can go either forward or
    # backward, and produces an event.
    def go
        return noop_event if noop?

        property.sync

        result = event()
        result.log = property.notice property.change_to_s(is, should)
        result.status = "success"
        result
    rescue => detail
        puts detail.backtrace if Puppet[:trace]
        result = event()
        result.status = "failure"

        is = property.is_to_s(is)
        should = property.should_to_s(should)
        result.log = property.err "change from #{is} to #{should} failed: #{detail}"
        result
    end

    def forward
        return self.go
    end

    # Is our property noop?  This is used for generating special events.
    def noop?
        return @property.noop
    end

    # The resource that generated this change.  This is used for handling events,
    # and the proxy resource is used for generated resources, since we can't
    # send an event to a resource we don't have a direct relationship with.  If we
    # have a proxy resource, then the events will be considered to be from
    # that resource, rather than us, so the graph resolution will still work.
    def resource
        self.proxy || @property.resource
    end

    def to_s
        return "change %s" % @property.change_to_s(@is, @should)
    end

    private

    def noop_event
        result = event
        result.log = property.log "is #{property.is_to_s(is)}, should be #{property.should_to_s(should)} (noop)"
        result.status = "noop"
        return result
    end
end
