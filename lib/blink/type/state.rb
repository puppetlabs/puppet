#!/usr/local/bin/ruby -w

# $Id$

require 'blink'
require 'blink/element'
require 'blink/statechange'

#---------------------------------------------------------------
# this is a virtual base class for states
# states are self-contained building blocks for objects

# States can currently only be used for comparing a virtual "should" value
# against the real state of the system.  For instance, you could verify that
# a file's owner is what you want, but you could not create two file objects
# and use these methods to verify that they have the same owner
module Blink
class Blink::State < Blink::Element
    attr_accessor :is, :should, :parent

    @virtual = true

    #---------------------------------------------------------------
    # every state class must tell us what its name will be (as a symbol)
    # this determines how we will refer to the state during usage
    # e.g., the Owner state for Files might say its name is :owner;
    # this means that we can say "file[:owner] = 'yayness'"
    def State.name
        return @name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # if we're not in sync, return a statechange capable of putting us
    # in sync
    def evaluate
        Blink.verbose "evaluating %s" % self
        self.retrieve
        if self.insync?
            Blink.verbose "%s is in sync" % self
            return nil
        else
            return Blink::StateChange.new(self)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return the full path to us, for logging and rollback
    def fqpath
        return @parent.fqpath, self.name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # we aren't actually comparing the states themselves, we're only
    # comparing the "should" value with the "is" value
    def insync?
        Blink.debug "%s value is '%s', should be '%s'" %
            [self,self.is.inspect,self.should.inspect]
        self.is == self.should
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def initialize(should)
        @is = nil
        @should = should
        @parent = nil
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        tmp = @noop || self.parent.noop || Blink[:noop] || false
        Blink.notice "noop is %s" % tmp
        return tmp
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def refresh(transaction)
        self.retrieve

        # we definitely need some way to batch these refreshes, so a
        # given object doesn't get refreshed multiple times in a single
        # run
        @parent.refresh
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # each state class must define the name() method, and state instances
    # do not change that name
    # this implicitly means that a given object can only have one state
    # instance of a given state class
    def name
        return self.class.name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # retrieve the current state from the running system
    def retrieve
        raise "'retrieve' method was not overridden by %s" % self.class
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        return @parent.name.to_s + " -> " + self.name.to_s
    end
    #---------------------------------------------------------------
end
end
