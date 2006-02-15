# The virtual base class for states, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/element'
require 'puppet/statechange'
require 'puppet/parameter'

module Puppet
class State < Puppet::Parameter
    attr_accessor :is

    # Because 'should' uses an array, we have a special method for handling
    # it.  We also want to keep copies of the original values, so that
    # they can be retrieved and compared later when merging.
    attr_reader :shouldorig

    class << self
        attr_accessor :unmanaged
        attr_reader :name

        #def inspect
        #    "State(%s)" % self.name
        #end

        #def to_s
        #    self.inspect
        #end
    end

    # Parameters just use 'newvalues', since there's no work associated with them.
    def self.newvalue(name, &block)
        @parametervalues ||= {}

        if @parametervalues.include?(name)
            Puppet.warning "%s already has a value for %s" % [name, name]
        end
        @parametervalues[name] = block

        define_method("set_" + name.to_s, &block)
    end

    # Call the method associated with a given value.
    def set
        if self.insync?
            self.log "already in sync"
            return nil
        end

        value = self.should
        method = "set_" + value.to_s
        unless self.respond_to?(method)
            self.fail "%s is not a valid value for %s" %
                [value, self.class.name]
        end
        self.debug "setting %s (currently %s)" % [value, self.is]

        begin
            event = self.send(method)
        rescue Puppet::Error
            raise
        rescue => detail
            if Puppet[:debug]
                puts detail.backtrace
            end
            self.fail "Could not set %s on %s: %s" %
                [value, self.class.name, detail]
        end

        if event and event.is_a?(Symbol)
            return event
        else
            # Return the appropriate event.
            event = case self.should
            when :present: (@parent.class.name.to_s + "_created").intern
            when :absent: (@parent.class.name.to_s + "_removed").intern
            else
                (@parent.class.name.to_s + "_changed").intern
            end

            #self.log "made event %s because 'should' is %s, 'is' is %s" %
            #    [event, self.should.inspect, self.is.inspect]

            return event
        end
    end
    
    # initialize our state
    def initialize(hash)
        super()
        @is = nil

        unless hash.include?(:parent)
            self.devfail "State %s was not passed a parent" % self
        end
        @parent = hash[:parent]

        if hash.include?(:should)
            self.should = hash[:should]
        end

        if hash.include?(:is)
            self.is = hash[:is]
        end
    end

    def inspect
        str = "State('%s', " % self.name
        if defined? @is and @is
            str += "@is = '%s', " % @is
        else
            str += "@is = nil, "
        end

        if defined? @should and @should
            str += "@should = '%s')" % @should.join(", ")
        else
            str += "@should = nil)"
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
            self.devfail "%s's should is not array" % self.class.name
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

    def log(msg)
        unless @parent[:loglevel]
            p @parent
            self.devfail "Parent %s has no loglevel" %
                @parent.name
        end
        Puppet::Log.create(
            :level => @parent[:loglevel],
            :message => msg,
            :source => self
        )
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
        return [@parent.path, self.name].join("/")
    end

    # Only return the first value
    def should
        if defined? @should
            unless @should.is_a?(Array)
                self.devfail "should for %s on %s is not an array" %
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

        if self.respond_to?(:validate)
            values.each { |val|
                validate(val)
            }
        end
        if self.respond_to?(:munge)
            @should = values.collect { |val|
                self.munge(val)
            }
        else
            @should = values
        end
    end

    # The default 'sync' method only selects among a list of registered
    # values.
    def sync
        if self.insync?
            self.info "already in sync"
            return nil
        #else
            #self.info "%s vs %s" % [self.is.inspect, self.should.inspect]
        end
        unless self.class.values
            self.devfail "No values defined for %s" %
                self.class.name
        end

        # Set ourselves to whatever our should value is.
        self.set
    end

    # How should a state change be printed as a string?
    def change_to_s
        begin
            if @is == :absent
                return "defined '%s' as '%s'" %
                    [self.name, self.should_to_s]
            elsif self.should == :absent or self.should == [:absent]
                return "undefined %s from '%s'" %
                    [self.name, self.is_to_s]
            else
                return "%s changed '%s' to '%s'" %
                    [self.name, self.is_to_s, self.should_to_s]
            end
        rescue Puppet::Error, Puppet::DevError
            raise
        rescue => detail
            raise Puppet::DevError, "Could not convert change %s to string: %s" %
                [self.name, detail]
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
        if defined? @should
            @should.join(" ")
        else
            return nil
        end
    end

    def to_s
        return "%s(%s)" % [@parent.name,self.name]
    end

    # This state will get automatically added to any type that responds
    # to the methods 'exists?', 'create', and 'destroy'.
    class Ensure < Puppet::State
        @name = :ensure

        def self.defaultvalues
            newvalue(:present) do
                @parent.create
            end

            newvalue(:absent) do
                @parent.destroy
            end

            # This doc will probably get overridden
            @doc ||= "The basic state that the object should be in."
        end

        def self.inherited(sub)
            # Add in the two states that everyone will have.
            sub.class_eval do
            end
        end

        def change_to_s
            begin
                if @is == :absent
                    return "created"
                elsif self.should == :absent
                    return "removed"
                else
                    return "%s changed '%s' to '%s'" %
                        [self.name, self.is_to_s, self.should_to_s]
                end
            rescue Puppet::Error, Puppet::DevError
                raise
            rescue => detail
                raise Puppet::DevError, "Could not convert change %s to string: %s" %
                    [self.name, detail]
            end
        end

        def retrieve
            # XXX This is a problem -- whether the object exists or not often
            # depends on the results of other states, yet we're the first state
            # to get checked, which means that those other states do not have
            # @is values set.  This seems to be the source of quite a few bugs,
            # although they're mostly logging bugs, not functional ones.
            if @parent.exists?
                @is = :present
            else
                @is = :absent
            end
        end

        # If they're talking about the thing at all, they generally want to
        # say it should exist.
        #defaultto :present
        defaultto do
            if @parent.managed?
                :present
            else
                nil
            end
        end
    end
end
end

# $Id$
