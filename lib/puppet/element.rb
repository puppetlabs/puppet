#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'puppet'


#---------------------------------------------------------------
# the base class for both types and states
# very little functionality; basically just defines the interface
# and provides a few simple across-the-board functions like 'noop'
class Puppet::Element
    include Puppet
    attr_writer :noop

    class << self
        attr_accessor :doc, :nodoc
    end

    #---------------------------------------------------------------
    # all of our subclasses must respond to each of these methods...
    @@interface_methods = [
        :retrieve, :insync?, :sync, :path, :evaluate
    ]

    # so raise an error if a method that isn't overridden gets called
    @@interface_methods.each { |method|
        self.send(:define_method,method) {
            raise Puppet::DevError, "%s has not overridden %s" %
                [self.class,method]
        }
    }
    #---------------------------------------------------------------

    # create instance methods for each of the log levels, too
    Puppet::Log.eachlevel { |level|
        define_method(level,proc { |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            Puppet::Log.create(
                :level => level,
                :source => self,
                :message => args
            )
        })
    }

    #---------------------------------------------------------------
    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        return @noop || Puppet[:noop] || false
    end
    #---------------------------------------------------------------

end
#---------------------------------------------------------------
