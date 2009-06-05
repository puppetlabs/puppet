#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

# subscriptions are permanent associations determining how different
# objects react to an event

# This is Puppet's class for modeling edges in its configuration graph.
# It used to be a subclass of GRATR::Edge, but that class has weird hash
# overrides that dramatically slow down the graphing.
class Puppet::Relationship
    attr_accessor :source, :target, :callback

    attr_reader :event

    def event=(event)
        if event != :NONE and ! callback
            raise ArgumentError, "You must pass a callback for non-NONE events"
        end
        @event = event
    end

    def initialize(source, target, options = {})
        @source, @target = source, target

        options ||= {}
        [:callback, :event].each do |option|
            if value = options[option]
                send(option.to_s + "=", value)
            end
        end
    end

    # Does the passed event match our event?  This is where the meaning
    # of :NONE comes from.
    def match?(event)
        if self.event.nil? or event == :NONE or self.event == :NONE
            return false
        elsif self.event == :ALL_EVENTS or event == self.event
            return true
        else
            return false
        end
    end

    def label
        result = {}
        result[:callback] = callback if callback
        result[:event] = event if event
        result
    end

    def ref
        "%s => %s" % [source, target]
    end

    def to_s
        ref
    end
end

