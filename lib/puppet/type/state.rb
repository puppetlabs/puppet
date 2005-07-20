#!/usr/local/bin/ruby -w

# $Id$

require 'puppet'
require 'puppet/element'
require 'puppet/statechange'

#---------------------------------------------------------------
# this is a virtual base class for states
# states are self-contained building blocks for objects

# States can currently only be used for comparing a virtual "should" value
# against the real state of the system.  For instance, you could verify that
# a file's owner is what you want, but you could not create two file objects
# and use these methods to verify that they have the same owner
module Puppet
class State < Puppet::Element
    attr_accessor :is, :should, :parent

    @virtual = true

    #---------------------------------------------------------------
    # which event gets generated if this state change happens; not currently
    # called
    def self.generates
        return @event
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # every state class must tell us what its name will be (as a symbol)
    # this determines how we will refer to the state during usage
    # e.g., the Owner state for Files might say its name is :owner;
    # this means that we can say "file[:owner] = 'yayness'"
    def self.name
        return @name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # if we're not in sync, return a statechange capable of putting us
    # in sync
    def evaluate
        #debug "evaluating %s" % self
        self.retrieve
        if self.insync?
            #debug "%s is in sync" % self
            return nil
        else
            return Puppet::StateChange.new(self)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # initialize our state
    def initialize(hash)
        @is = nil

        unless hash.include?(:parent)
            raise "State %s was not passed a parent" % self
        end
        @parent = hash[:parent]

        if hash.include?(:should)
            self.should = hash[:should]
        else # we got passed no argument
            # leave @should undefined
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # we aren't actually comparing the states themselves, we're only
    # comparing the "should" value with the "is" value
    def insync?
        #debug "%s value is '%s', should be '%s'" %
        #    [self,self.is.inspect,self.should.inspect]
        self.is == self.should
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
    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        tmp = @noop || self.parent.noop || Puppet[:noop] || false
        #debug "noop is %s" % tmp
        return tmp
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return the full path to us, for logging and rollback; not currently
    # used
    def path
        return [@parent.path, self.name].flatten
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        return "%s(%s)" % [@parent.name,self.name]
    end
    #---------------------------------------------------------------
end
end
