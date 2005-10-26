# The virtual base class for states, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/element'
require 'puppet/statechange'

module Puppet
class State < Puppet::Element
    attr_accessor :is, :parent

    # Because 'should' uses an array, we have a special method for handling
    # it.  We also want to keep copies of the original values, so that
    # they can be retrieved and compared later when merging.
    attr_reader :shouldorig

    @virtual = true

    class << self
        attr_accessor :unmanaged
        attr_reader :name
    end

    # initialize our state
    def initialize(hash)
        @is = nil

        unless hash.include?(:parent)
            raise "State %s was not passed a parent" % self
        end
        @parent = hash[:parent]

        if hash.include?(:should)
            self.should = hash[:should]
        end

        if hash.include?(:is)
            self.is = hash[:is]
        end
    end

    # Determine whether the state is in-sync or not.  If @should is
    # not defined or is set to a non-true value, then we do not have
    # a valid value for it and thus consider the state to be in-sync
    # since we cannot fix it.  Otherwise, we expect our should value
    # to be an array, and if @is matches any of those values, then
    # we consider it to be in-sync.
    def insync?
        #debug "%s value is '%s', should be '%s'" %
        #    [self,self.is.inspect,self.should.inspect]
        unless defined? @should and @should
            return true
        end

        unless @should.is_a?(Array)
            raise Puppet::DevError, "%s's should is not array" % self.class.name
        end

        # an empty array is analogous to no should values
        if @should.empty?
            return true
        end

        # Look for a matching value
        @should.each { |val|
            if @is == val
                return true
            end
        }

        # otherwise, return false
        return false
    end

    # each state class must define the name() method, and state instances
    # do not change that name
    # this implicitly means that a given object can only have one state
    # instance of a given state class
    def name
        return self.class.name
    end

    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        tmp = @noop || self.parent.noop || Puppet[:noop] || false
        #debug "noop is %s" % tmp
        return tmp
    end

    # return the full path to us, for logging and rollback; not currently
    # used
    def path
        return [@parent.path, self.name].flatten
    end

    # Only return the first value
    def should
        if defined? @should
            unless @should.is_a?(Array)
                self.warning @should.inspect
                raise Puppet::DevError, "should for %s on %s is not an array" %
                    [self.class.name, @parent.name]
            end
            return @should[0]
        else
            return nil
        end
    end

    # Set the should value.
    def should=(values)
        unless values.is_a?(Array)
            values = [values]
        end

        @shouldorig = values

        if self.respond_to?(:shouldprocess)
            @should = values.collect { |val|
                self.shouldprocess(val)
            }
        else
            @should = values
        end
    end


    # How should a state change be printed as a string?
    def change_to_s
        if @is == :notfound
            return "%s: defined '%s' as '%s'" %
                [@parent, self.name, self.should_to_s]
        elsif self.should == :notfound
            return "%s: undefined %s from '%s'" %
                [self.parent, self.name, self.is_to_s]
        else
            return "%s changed '%s' to '%s'" %
                [self.name, self.is_to_s, self.should_to_s]
        end
    end

    # because the @should and @is vars might be in weird formats,
    # we need to set up a mechanism for pretty printing of the values
    # default to just the values, but this way individual states can
    # override these methods
    def is_to_s
        @is
    end

    def should_to_s
        @should
    end

    def to_s
        return "%s(%s)" % [@parent.name,self.name]
    end
end
end

# $Id$
