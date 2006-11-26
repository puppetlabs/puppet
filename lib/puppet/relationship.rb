#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/gratr'

# subscriptions are permanent associations determining how different
# objects react to an event

class Puppet::Relationship < GRATR::Edge
    # Return the callback
    def callback
        label[:callback]
    end
    
    # Return our event.
    def event
        label[:event]
    end
    
    def initialize(source, target, label = nil)
        if label
            unless label.is_a?(Hash)
                raise Puppet::DevError, "The label must be a hash"
            end
        
            if label[:event] and label[:event] != :NONE and ! label[:callback]
                raise Puppet::DevError, "You must pass a callback for non-NONE events"
            end
        else
            label = {}
        end
        
        super(source, target, label)
    end
    
    # Does the passed event match our event?  This is where the meaning
    # of :NONE comes from. 
    def match?(event)
        if event == :NONE or self.event == :NONE
            return false
        elsif self.event == :ALL_EVENTS or event == :ALL_EVENTS or event == self.event
            return true
        else
            return false
        end
    end
end

# $Id$
