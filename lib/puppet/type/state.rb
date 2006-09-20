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

        def checkable
            @checkable = true
        end

        def uncheckable
            @checkable = false
        end

        def checkable?
            if defined? @checkable
                return @checkable
            else
                return true
            end
        end
    end

    # Only retrieve the event, don't autogenerate one.
    def self.event(value)
        if hash = @parameteroptions[value]
            hash[:event]
        else
            nil
        end
    end

    # Create the value management variables.
    def self.initvars
        @parametervalues = {}
        @aliasvalues = {}
        @parameterregexes = {}
        @parameteroptions = {}
    end

    # Define a new valid value for a state.  You must provide the value itself,
    # usually as a symbol, or a regex to match the value.
    #
    # The first argument to the method is either the value itself or a regex.
    # The second argument is an option hash; valid options are:
    # * <tt>:event</tt>: The event that should be returned when this value is set.
    def self.newvalue(name, options = {}, &block)
        name = name.intern if name.is_a? String

        @parameteroptions[name] = {}
        paramopts = @parameteroptions[name]

        # Symbolize everything
        options.each do |opt, val|
            paramopts[symbolize(opt)] = symbolize(val)
        end

        case name
        when Symbol
            if @parametervalues.include?(name)
                Puppet.warning "%s reassigning value %s" % [self.name, name]
            end
            @parametervalues[name] = block

            method = "set_" + name.to_s
            settor = paramopts[:settor] || (self.name.to_s + "=")
            define_method(method, &block)
        when Regexp
            # The regexes are handled in parameter.rb
            @parameterregexes[name] = block
        else
            raise ArgumentError, "Invalid value %s of type %s" %
                [name, name.class]
        end
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
        if self.is
            str += "@is = '%s', " % [self.is]
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

    # because the @should and @is vars might be in weird formats,
    # we need to set up a mechanism for pretty printing of the values
    # default to just the values, but this way individual states can
    # override these methods
    def is_to_s
        @is
    end

    # Send a log message.
    def log(msg)
        unless @parent[:loglevel]
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
        if defined? @parent and @parent
            return [@parent.path, self.name].join("/")
        else
            return self.name
        end
    end

    # Retrieve the parent's provider.  Some types don't have providers, in which
    # case we return the parent object itself.
    def provider
        @parent.provider || @parent
    end

    # By default, call the method associated with the state name on our
    # provider.  In other words, if the state name is 'gid', we'll call
    # 'provider.gid' to retrieve the current value.
    def retrieve
        @is = provider.send(self.class.name)
    end

    # Call the method associated with a given value.
    def set
        if self.insync?
            self.log "already in sync"
            return nil
        end

        value = self.should
        method = "set_" + value.to_s
        event = nil
        if self.respond_to?(method)
            self.debug "setting %s (currently %s)" % [value, self.is]

            begin
                event = self.send(method)
            rescue Puppet::Error
                raise
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                self.fail "Could not set %s on %s: %s" %
                    [value, self.class.name, detail]
            end
        elsif ary = self.class.match?(value)
            # FIXME It'd be better here to define a method, so that
            # the blocks could return values.
            event = self.instance_eval(&ary[1])
        else
            begin
                provider.send(self.class.name.to_s + "=", self.should)
            rescue NoMethodError
                self.fail "The %s provider can not handle attribute %s" %
                    [provider.class.name, self.class.name]
            end
        end

        if setevent = self.class.event(value)
            return setevent
        else
            if event and event.is_a?(Symbol)
                if event == :nochange
                    return nil
                else
                    return event
                end
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

    def should_to_s
        if defined? @should
            @should.join(" ")
        else
            return nil
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

    # The states need to return tags so that logs correctly collect them.
    def tags
        unless defined? @tags
            @tags = []
            # This might not be true in testing
            if @parent.respond_to? :tags
                @tags = @parent.tags
            end
            @tags << self.name
        end
        @tags
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
