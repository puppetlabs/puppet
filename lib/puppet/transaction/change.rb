require 'puppet/transaction'
require 'puppet/transaction/event'

# Handle all of the work around performing an actual change,
# including calling 'sync' on the properties and producing events.
class Puppet::Transaction::Change
    attr_accessor :is, :should, :path, :property, :changed, :proxy

    # Switch the goals of the property, thus running the change in reverse.
    def backward
        @is, @should = @should, @is
        @property.should = @should

        @property.info "Reversing %s" % self
        return self.go
    end

    def changed?
        self.changed
    end

    # Create our event object.
    def event(name)
        # default to a simple event type
        unless name.is_a?(Symbol)
            @property.warning("Property '%s' returned invalid event '%s'; resetting to default" %
                [@property.class, name])

            name = @property.event(should)
        end

        Puppet::Transaction::Event.new(name, self.resource)
    end

    def initialize(property, currentvalue)
        @property = property
        @path = [property.path,"change"].flatten
        @is = currentvalue

        @should = property.should

        @changed = false
    end

    # Perform the actual change.  This method can go either forward or
    # backward, and produces an event.
    def go
        if self.noop?
            @property.log "is %s, should be %s (noop)" % [property.is_to_s(@is), property.should_to_s(@should)]
            return [event(:noop)]
        end

        # The transaction catches any exceptions here.
        events = @property.sync
        if events.nil?
            events = [(@property.name.to_s + "_changed").to_sym]
        elsif events.is_a?(Array)
            if events.empty?
                events = [(@property.name.to_s + "_changed").to_sym]
            end
        else
            events = [events]
        end

        return events.collect { |name|
            @report = @property.log(@property.change_to_s(@is, @should))
            event(name)
        }
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
    # send an event to a resource we don't have a direct relationship.  If we
    # have a proxy resource, then the events will be considered to be from
    # that resource, rather than us, so the graph resolution will still work.
    def resource
        self.proxy || @property.resource
    end

    def to_s
        return "change %s" % @property.change_to_s(@is, @should)
    end
end
