#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'blink'
require 'blink/type'


#---------------------------------------------------------------
# here i'm separating out the methods dealing with handling events
# currently not in use, so...

class Blink::Type
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
        Blink.debug "#{self} got event #{event} from #{obj}"
        if @actions.key?(event)
            Blink.debug "calling it"
            @actions[event].call(self,obj,event)
        else
            p @actions
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def newevent(args)
        if args[:event].nil?
            raise "newevent called wrong on #{self}"
        end

        return Blink::Event.new(
            :event => args[:event],
            :object => self
        )
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
                Blink.debug "pushing event '%s' for object '%s'" % [event,obj]
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
        Blink.debug "triggering #{event}"
        subscribers.each { |obj|
            Blink.debug "calling #{event} on #{obj}"
            obj.event(event,self)
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
end # Blink::Type
