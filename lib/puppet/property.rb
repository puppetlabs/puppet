 # The virtual base class for properties, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/parameter'

module Puppet
class Property < Puppet::Parameter

    # Because 'should' uses an array, we have a special method for handling
    # it.  We also want to keep copies of the original values, so that
    # they can be retrieved and compared later when merging.
    attr_reader :shouldorig

    attr_writer :noop

    class << self
        attr_accessor :unmanaged
        attr_reader :name

        # Return array matching info, defaulting to just matching
        # the first value.
        def array_matching
            unless defined?(@array_matching)
                @array_matching = :first
            end
            @array_matching
        end

        # Set whether properties should match all values or just the first one.
        def array_matching=(value)
            value = value.intern if value.is_a?(String)
            unless [:first, :all].include?(value)
                raise ArgumentError, "Supported values for Property#array_matching are 'first' and 'all'"
            end
            @array_matching = value
        end

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

    # Look up a value's name, so we can find options and such.
    def self.value_name(value)
        if value != '' and name = symbolize(value) and @parametervalues.include?(name)
            return name
        elsif ary = self.match?(value)
            return ary[0]
        else
            return nil
        end
    end

    # Retrieve an option set when a value was defined.
    def self.value_option(name, option)
        option = option.to_sym
        if hash = @parameteroptions[name]
            hash[option]
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

    # Define a new valid value for a property.  You must provide the value itself,
    # usually as a symbol, or a regex to match the value.
    #
    # The first argument to the method is either the value itself or a regex.
    # The second argument is an option hash; valid options are:
    # * <tt>:event</tt>: The event that should be returned when this value is set.
    # * <tt>:call</tt>: When to call any associated block.  The default value
    #   is ``instead``, which means to call the value instead of calling the
    #   provider.  You can also specify ``before`` or ``after``, which will 
    #   call both the block and the provider, according to the order you specify
    #   (the ``first`` refers to when the block is called, not the provider).
    def self.newvalue(name, options = {}, &block)
        name = name.intern if name.is_a? String

        @parameteroptions[name] = {}
        paramopts = @parameteroptions[name]

        # Symbolize everything
        options.each do |opt, val|
            paramopts[symbolize(opt)] = symbolize(val)
        end

        # By default, call the block instead of the provider.
        if block_given?
            paramopts[:call] ||= :instead
        else
            paramopts[:call] ||= :none
        end
        # If there was no block given, we still want to store the information
        # for validation, but we won't be defining a method
        block ||= true

        case name
        when Symbol
            if @parametervalues.include?(name)
                Puppet.warning "%s reassigning value %s" % [self.name, name]
            end
            @parametervalues[name] = block

            if block_given?
                method = "set_" + name.to_s
                settor = paramopts[:settor] || (self.name.to_s + "=")
                define_method(method, &block)
                paramopts[:method] = method
            end
        when Regexp
            # The regexes are handled in parameter.rb.  This value is used
            # for validation.
            @parameterregexes[name] = block

            # This is used for looking up the block for execution.
            if block_given?
                paramopts[:block] = block
            end
        else
            raise ArgumentError, "Invalid value %s of type %s" %
                [name, name.class]
        end
    end

    # Call the provider method.
    def call_provider(value)
        begin
            provider.send(self.class.name.to_s + "=", value)
        rescue NoMethodError
            self.fail "The %s provider can not handle attribute %s" %
                [provider.class.name, self.class.name]
        end
    end

    # Call the dynamically-created method associated with our value, if
    # there is one.
    def call_valuemethod(name, value)
        event = nil
        if method = self.class.value_option(name, :method) and self.respond_to?(method)
            #self.debug "setting %s (currently %s)" % [value, self.retrieve]

            begin
                event = self.send(method)
            rescue Puppet::Error
                raise
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                error = Puppet::Error.new("Could not set %s on %s: %s" %
                    [value, self.class.name, detail], @resource.line, @resource.file)
                error.set_backtrace detail.backtrace
                raise error
            end
        elsif block = self.class.value_option(name, :block)
            # FIXME It'd be better here to define a method, so that
            # the blocks could return values.
            # If the regex was defined with no associated block, then just pass
            # through and the correct event will be passed back.
            event = self.instance_eval(&block)
        end
        return event, name
    end

    # How should a property change be printed as a string?
    def change_to_s(currentvalue, newvalue)
        begin
            if currentvalue == :absent
                return "defined '%s' as '%s'" %
                    [self.name, self.should_to_s(newvalue)]
            elsif newvalue == :absent or newvalue == [:absent]
                return "undefined %s from '%s'" %
                    [self.name, self.is_to_s(currentvalue)]
            else
                return "%s changed '%s' to '%s'" %
                    [self.name, self.is_to_s(currentvalue), self.should_to_s(newvalue)]
            end
        rescue Puppet::Error, Puppet::DevError
            raise
        rescue => detail
            raise Puppet::DevError, "Could not convert change %s to string: %s" %
                [self.name, detail]
        end
    end

    # Figure out which event to return.
    def event(name, event = nil)
        if value_event = self.class.value_option(name, :event)
            return value_event 
        end

        if event and event.is_a?(Symbol)
            if event == :nochange
                return nil
            else
                return event
            end
        end

        if self.class.name == :ensure
            event = case self.should
            when :present: (@resource.class.name.to_s + "_created").intern
            when :absent: (@resource.class.name.to_s + "_removed").intern
            else
                (@resource.class.name.to_s + "_changed").intern
            end
        else
            event = (@resource.class.name.to_s + "_changed").intern
        end

        return event
    end
    
    # initialize our property
    def initialize(hash = {})
        super
    end

    def inspect
        str = "Property('%s', " % self.name

        if defined? @should and @should
            str += "@should = '%s')" % @should.join(", ")
        else
            str += "@should = nil)"
        end
    end

    # Determine whether the property is in-sync or not.  If @should is
    # not defined or is set to a non-true value, then we do not have
    # a valid value for it and thus consider the property to be in-sync
    # since we cannot fix it.  Otherwise, we expect our should value
    # to be an array, and if @is matches any of those values, then
    # we consider it to be in-sync.
    def insync?(is)
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
        if match_all?
            return (is == @should or is == @should.collect { |v| v.to_s })
        else
            @should.each { |val|
                if is == val or is == val.to_s
                    return true
                end
            }
        end

        # otherwise, return false
        return false
    end

    # because the @should and @is vars might be in weird formats,
    # we need to set up a mechanism for pretty printing of the values
    # default to just the values, but this way individual properties can
    # override these methods
    def is_to_s(currentvalue)
        currentvalue
    end

    # Send a log message.
    def log(msg)
        unless @resource[:loglevel]
            self.devfail "Parent %s has no loglevel" % @resource.name
        end
        Puppet::Util::Log.create(
            :level => @resource[:loglevel],
            :message => msg,
            :source => self
        )
    end

    # Should we match all values, or just the first?
    def match_all?
        self.class.array_matching == :all
    end

    # each property class must define the name() method, and property instances
    # do not change that name
    # this implicitly means that a given object can only have one property
    # instance of a given property class
    def name
        return self.class.name
    end

    # for testing whether we should actually do anything
    def noop
        # This is only here to make testing easier.
        if @resource.respond_to?(:noop?)
            @resource.noop?
        else
            if defined?(@noop)
                @noop
            else
                Puppet[:noop]
            end
        end
    end

    # By default, call the method associated with the property name on our
    # provider.  In other words, if the property name is 'gid', we'll call
    # 'provider.gid' to retrieve the current value.
    def retrieve
        provider.send(self.class.name)
    end

    # Set our value, using the provider, an associated block, or both.
    def set(value)
        # Set a name for looking up associated options like the event.
        name = self.class.value_name(value)

        call = self.class.value_option(name, :call)

        # If we're supposed to call the block first or instead, call it now
        if call == :before or call == :instead
            event, tmp = call_valuemethod(name, value) 
        end
        unless call == :instead
            if @resource.provider
                call_provider(value)
            else
                # They haven't provided a block, and our parent does not have
                # a provider, so we have no idea how to handle this.
                self.fail "%s cannot handle values of type %s" %
                    [self.class.name, value.inspect]
            end
        end
        if call == :after
            event, tmp = call_valuemethod(name, value) 
        end

        return event(name, event)
    end

    # Only return the first value
    def should
        if defined? @should
            unless @should.is_a?(Array)
                self.devfail "should for %s on %s is not an array" %
                    [self.class.name, @resource.name]
            end
            if match_all?
                return @should
            else
                return @should[0]
            end
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

    def should_to_s(newvalue)
        newvalue = [newvalue] unless newvalue.is_a? Array
        if defined? newvalue
            newvalue.join(" ")
        else
            return nil
        end
    end

    # The default 'sync' method only selects among a list of registered # values.
    def sync
        self.devfail("No values defined for %s" % self.class.name) unless self.class.values

        if value = self.should
            set(value)
        else
            self.devfail "Got a nil value for should"
        end
    end

    # The properties need to return tags so that logs correctly collect them.
    def tags
        unless defined? @tags
            @tags = []
            # This might not be true in testing
            if @resource.respond_to? :tags
                @tags = @resource.tags
            end
            @tags << self.name
        end
        @tags
    end

    def to_s
        return "%s(%s)" % [@resource.name,self.name]
    end

    # Just return any should value we might have.
    def value
        self.should
    end

    # Match the Parameter interface, but we really just use 'should' internally.
    # Note that the should= method does all of the validation and such.
    def value=(value)
        self.should = value
    end

    # This property will get automatically added to any type that responds
    # to the methods 'exists?', 'create', and 'destroy'.
    class Ensure < Puppet::Property
        @name = :ensure

        def self.defaultvalues
            newvalue(:present) do
                if @resource.provider and @resource.provider.respond_to?(:create)
                    @resource.provider.create
                else
                    @resource.create
                end
                nil # return nil so the event is autogenerated
            end

            newvalue(:absent) do
                if @resource.provider and @resource.provider.respond_to?(:destroy)
                    @resource.provider.destroy
                else
                    @resource.destroy
                end
                nil # return nil so the event is autogenerated
            end

            defaultto do
                if @resource.managed?
                    :present
                else
                    nil
                end
            end

            # This doc will probably get overridden
            @doc ||= "The basic property that the resource should be in."
        end

        def self.inherited(sub)
            # Add in the two properties that everyone will have.
            sub.class_eval do
            end
        end

        def change_to_s(currentvalue, newvalue)
            begin
                if currentvalue == :absent or currentvalue.nil?
                    return "created"
                elsif newvalue == :absent
                    return "removed"
                else
                    return "%s changed '%s' to '%s'" %
                        [self.name, self.is_to_s(currentvalue), self.should_to_s(newvalue)]
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
            # depends on the results of other properties, yet we're the first property
            # to get checked, which means that those other properties do not have
            # @is values set.  This seems to be the source of quite a few bugs,
            # although they're mostly logging bugs, not functional ones.
            if prov = @resource.provider and prov.respond_to?(:exists?)
                result = prov.exists?
            elsif @resource.respond_to?(:exists?)
                result = @resource.exists?
            else
                raise Puppet::DevError, "No ability to determine if %s exists" %
                    @resource.class.name
            end
            if result
                return :present
            else
                return :absent
            end
        end

        # If they're talking about the thing at all, they generally want to
        # say it should exist.
        #defaultto :present
        defaultto do
            if @resource.managed?
                :present
            else
                nil
            end
        end
    end
end
end

