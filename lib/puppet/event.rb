#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'puppet'
require 'puppet/type'

module Puppet
    # events are transient packets of information; they result in one or more (or none)
    # subscriptions getting triggered, and then they get cleared
    # eventually, these will be passed on to some central event system
	class Event
        # subscriptions are permanent associations determining how different
        # objects react to an event
        class Subscription
            attr_accessor :source, :event, :target, :method

            def initialize(hash)
                @triggered = false

                hash.each { |method,value|
                    # assign each value appropriately
                    # this is probably wicked-slow
                    self.send(method.to_s + "=",value)
                }
                Puppet.debug "New Subscription: '%s' => '%s'" %
                    [@source,@event]
            end

            # the transaction is passed in so that we can notify it if
            # something fails
            def trigger(transaction)
                # this is potentially incomplete, because refreshing an object
                # could theoretically kick off an event, which would not get run
                # or, because we're executing the first subscription rather than
                # the last, a later-refreshed object could somehow be connected
                # to the "old" object rather than "new"
                # but we're pretty far from that being a problem
                if transaction.triggercount(self) > 0
                    Puppet.debug "%s has already run" % self
                else
                    Puppet.debug "'%s' matched '%s'; triggering '%s' on '%s'" %
                        [@source,@event,@method,@target]
                    begin
                        if @target.respond_to?(@method)
                            @target.send(@method)
                        else
                            Puppet.debug "'%s' of type '%s' does not respond to '%s'" %
                                [@target,@target.class,@method.inspect]
                        end
                    rescue => detail
                        # um, what the heck do i do when an object fails to refresh?
                        # shouldn't that result in the transaction rolling back?
                        # XXX yeah, it should
                        Puppet.err "'%s' failed to %s: '%s'" %
                            [@target,@method,detail]
                        raise
                        #raise "We need to roll '%s' transaction back" %
                            #transaction
                    end
                    transaction.triggered(self)
                end
            end
        end

		attr_accessor :event, :object, :transaction

        @@events = []

        @@subscriptions = []

        def Event.process
            Puppet.debug "Processing events"
            @@events.each { |event|
                @@subscriptions.find_all { |sub|
                    #Puppet.debug "Sub source: '%s'; event object: '%s'" %
                    #    [sub.source.inspect,event.object.inspect]
                    sub.source == event.object and
                        (sub.event == event.event or
                         sub.event == :ALL_EVENTS)
                }.each { |sub|
                    Puppet.debug "Found subscription to %s" % event
                    sub.trigger(event.transaction)
                }
            }

            @@events.clear
        end

        def Event.subscribe(hash)
            if hash[:event] == '*'
                hash[:event] = :ALL_EVENTS
            end
            sub = Subscription.new(hash)

            # add to the correct area
            @@subscriptions.push sub
        end

		def initialize(args)
            unless args.include?(:event) and args.include?(:object)
				raise "Event.new called incorrectly"
			end

			@event = args[:event]
			@object = args[:object]
			@transaction = args[:transaction]

            Puppet.info "%s: %s" %
                [@object,@event]

            # initially, just stuff all instances into a central bucket
            # to be handled as a batch
            @@events.push self
		end
	end
end


#---------------------------------------------------------------
# here i'm separating out the methods dealing with handling events
# currently not in use, so...

class Puppet::NotUsed
    #---------------------------------------------------------------
    # return action array
    # these are actions to use for responding to events
    # no, this probably isn't the best way, because we're providing
    # access to the actual hash, which is silly
    def action
        if not defined? @actions
            puts "defining action hash"
            @actions = Hash.new
        end
        @actions
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # call an event
    # this is called on subscribers by the trigger method from the obj
    # which sent the event
    # event handling should probably be taking place in a central process,
    # but....
    def event(event,obj)
        Puppet.debug "#{self} got event #{event} from #{obj}"
        if @actions.key?(event)
            Puppet.debug "calling it"
            @actions[event].call(self,obj,event)
        else
            p @actions
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # subscribe to an event or all events
    # this entire event system is a hack job and needs to
    # be replaced with a central event handler
    def subscribe(args,&block)
        obj = args[:object]
        event = args[:event] || '*'.intern
        if obj.nil? or event.nil?
            raise "subscribe was called wrongly; #{obj} #{event}"
        end
        obj.action[event] = block
        #events.each { |event|
            unless @notify.key?(event)
                @notify[event] = Array.new
            end
            unless @notify[event].include?(obj)
                Puppet.debug "pushing event '%s' for object '%s'" % [event,obj]
                @notify[event].push(obj)
            end
        #	}
        #else
        #	@notify['*'.intern].push(obj)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # initiate a response to an event
    def trigger(event)
        subscribers = Array.new
        if @notify.include?('*') and @notify['*'].length > 0
            @notify['*'].each { |obj| subscribers.push(obj) }
        end
        if (@notify.include?(event) and (! @notify[event].empty?) )
            @notify[event].each { |obj| subscribers.push(obj) }
        end
        Puppet.debug "triggering #{event}"
        subscribers.each { |obj|
            Puppet.debug "calling #{event} on #{obj}"
            obj.event(event,self)
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
end # Puppet::Type
