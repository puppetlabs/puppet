#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'blink'


#---------------------------------------------------------------
# the base class for both types and states
# very little functionality; basically just defines the interface
# and provides a few simple across-the-board functions like 'noop'
class Blink::Element
    attr_writer :noop

    #---------------------------------------------------------------
    # all of our subclasses must respond to each of these methods...
    @@interface_methods = [
        :retrieve, :insync?, :sync, :fqpath, :evaluate, :refresh
    ]

    # so raise an error if a method that isn't overridden gets called
    @@interface_methods.each { |method|
        self.send(:define_method,method) {
            raise "%s has not overridden %s" % [self.class,method]
        }
    }
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        return @noop || Blink[:noop] || false
    end
    #---------------------------------------------------------------

end
#---------------------------------------------------------------
