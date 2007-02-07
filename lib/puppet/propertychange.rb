# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Puppet
    # Handle all of the work around performing an actual change,
    # including calling 'sync' on the properties and producing events.
	class PropertyChange
        attr_accessor :is, :should, :type, :path, :property, :transaction, :changed, :proxy
        
        # The log file generated when this object was changed.
        attr_reader :report
        
        # Switch the goals of the property, thus running the change in reverse.
        def backward
            @property.should = @is
            @property.retrieve

            unless defined? @transaction
                raise Puppet::Error,
                    "PropertyChange '%s' tried to be executed outside of transaction" %
                    self
            end
            unless @property.insync?
                @property.info "Backing %s" % self
                return self.go
            else
                @property.debug "rollback is already in sync: %s vs. %s" %
                    [@property.is.inspect, @property.should.inspect]
                return nil
            end
        end
        
        def changed?
            self.changed
        end

        def initialize(property)
            unless property.is_a?(Puppet::Type::Property)
                raise Puppet::DevError, "Got a %s instead of a property" %
                    property.class
            end
            @property = property
            @path = [property.path,"change"].flatten
            @is = property.is

            @should = property.should

            @changed = false
        end

        # Perform the actual change.  This method can go either forward or
        # backward, and produces an event.
        def go
            return nil if skip?

            # The transaction catches any exceptions here.
            events = @property.sync
            if events.nil?
                return nil
            end

            if events.is_a?(Array)
                if events.empty?
                    return nil
                end
            else
                events = [events]
            end
            
            return events.collect { |event|
                # default to a simple event type
                unless event.is_a?(Symbol)
                    @property.warning("Property '%s' returned invalid event '%s'; resetting to default" %
                        [@property.class,event])

                    event = @property.parent.class.name.id2name + "_changed"
                end
                
                @report = @property.log(@property.change_to_s)
                Puppet::Event.new(
                    :event => event,
                    :transaction => @transaction,
                    :source => self.source
                )
            }
        end

        def forward
            #@property.debug "moving change forward"

            unless defined? @transaction
                raise Puppet::Error,
                    "PropertyChange '%s' tried to be executed outside of transaction" %
                    self
            end

            return self.go
        end
        
        def noop
            return @property.noop
        end
        
        def skip?
            if @property.insync?
                @property.info "Already in sync"
                return true
            end

            if @property.noop
                @property.log "is %s, should be %s (noop)" %
                    [property.is_to_s, property.should_to_s]
                #@property.debug "%s is noop" % @property
                return true
            end
            return false
        end
        
        def source
            self.proxy || @property.parent
        end

        def to_s
            return "change %s.%s(%s)" %
                [@transaction.object_id, self.object_id, @property.change_to_s]
            #return "change %s.%s" % [@transaction.object_id, self.object_id]
        end
	end
end

# $Id$
