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
    def event(event_name)
        event_name ||= property.default_event_name(should)

        # default to a simple event type
        unless event_name.is_a?(Symbol)
            @property.warning "Property '#{property.class}' returned invalid event '#{event_name}'; resetting to default"

            event_name = property.default_event_name(should)
        end

        Puppet::Transaction::Event.new(event_name, resource.ref, property.name, is, should)
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
        if self.noop?
            @property.log "is %s, should be %s (noop)" % [property.is_to_s(@is), property.should_to_s(@should)]
            return event(:noop)
        end

        # The transaction catches any exceptions here.
        event_name = @property.sync

        # Use the first event only, if multiple are provided.
        # This might result in the event_name being nil,
        # which is fine.
        event_name = event_name.shift if event_name.is_a?(Array)

        event = event(event_name)
        event.log = @property.notice @property.change_to_s(@is, @should)
        event.status = "success"
        event
    rescue => detail
        puts detail.backtrace if Puppet[:trace]
        event = event(nil)
        event.status = "failure"

        is = property.is_to_s(is)
        should = property.should_to_s(should)
        event.log = property.err "change from #{is} to #{should} failed: #{detail}"
        event
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
end
