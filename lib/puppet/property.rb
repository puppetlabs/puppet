# The virtual base class for properties, which are the self-contained building
# blocks for actually doing work on the system.

require 'puppet'
require 'puppet/parameter'

class Puppet::Property < Puppet::Parameter

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
    def self.value_name(name)
        if value = value_collection.match?(name)
            value.name
        end
    end

    # Retrieve an option set when a value was defined.
    def self.value_option(name, option)
        if value = value_collection.value(name)
            value.send(option)
        end
    end

    # Define a new valid value for a property.  You must provide the value itself,
    # usually as a symbol, or a regex to match the value.
    #
    # The first argument to the method is either the value itself or a regex.
    # The second argument is an option hash; valid options are:
    # * <tt>:method</tt>: The name of the method to define.  Defaults to 'set_<value>'.
    # * <tt>:required_features</tt>: A list of features this value requires.
    # * <tt>:event</tt>: The event that should be returned when this value is set.
    # * <tt>:call</tt>: When to call any associated block.  The default value
    #   is ``instead``, which means to call the value instead of calling the
    #   provider.  You can also specify ``before`` or ``after``, which will
    #   call both the block and the provider, according to the order you specify
    #   (the ``first`` refers to when the block is called, not the provider).
    def self.newvalue(name, options = {}, &block)
        value = value_collection.newvalue(name, options, &block)

        if value.method and value.block
            define_method(value.method, &value.block)
        end
        value
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
            event = self.instance_eval(&block)
        else
            devfail "Could not find method for value '%s'" % name
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
            puts detail.backtrace if Puppet[:trace]
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
            when :present; (@resource.class.name.to_s + "_created").intern
            when :absent; (@resource.class.name.to_s + "_removed").intern
            else
                (@resource.class.name.to_s + "_changed").intern
            end
        else
            event = (@resource.class.name.to_s + "_changed").intern
        end

        return event
    end

    attr_reader :shadow

    # initialize our property
    def initialize(hash = {})
        super

        if ! self.metaparam? and klass = Puppet::Type.metaparamclass(self.class.name)
            setup_shadow(klass)
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

    # Execute our shadow's munge code, too, if we have one.
    def munge(value)
        self.shadow.munge(value) if self.shadow

        super
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

        call = self.class.value_option(name, :call) || :none

        if call == :instead
            event, tmp = call_valuemethod(name, value)
        elsif call == :none
            if @resource.provider
                call_provider(value)
            else
                # They haven't provided a block, and our parent does not have
                # a provider, so we have no idea how to handle this.
                self.fail "%s cannot handle values of type %s" % [self.class.name, value.inspect]
            end
        else
            # LAK:NOTE 20081031 This is a change in behaviour -- you could
            # previously specify :call => [;before|:after], which would call
            # the setter *in addition to* the block.  I'm convinced this
            # was never used, and it makes things unecessarily complicated.
            # If you want to specify a block and still call the setter, then
            # do so in the block.
            devfail "Cannot use obsolete :call value '%s' for property '%s'" % [call, self.class.name]
        end

        return event(name, event)
    end

    # If there's a shadowing metaparam, instantiate it now.
    # This allows us to create a property or parameter with the
    # same name as a metaparameter, and the metaparam will only be
    # stored as a shadow.
    def setup_shadow(klass)
        @shadow = klass.new(:resource => self.resource)
    end

    # Only return the first value
    def should
        if defined? @should
            unless @should.is_a?(Array)
                self.devfail "should for %s on %s is not an array" %
                    [self.class.name, @resource.name]
            end
            if match_all?
                return @should.collect { |val| self.unmunge(val) }
            else
                return self.unmunge(@should[0])
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

        values.each { |val| validate(val) }
        @should = values.collect { |val| self.munge(val) }
    end

    def should_to_s(newvalue)
        [newvalue].flatten.join(" ")
    end

    def sync
        devfail "Got a nil value for should" unless should
        set(should)
    end

    def to_s
        return "%s(%s)" % [@resource.name,self.name]
    end

    # Verify that the passed value is valid.
    # If the developer uses a 'validate' hook, this method will get overridden.
    def unsafe_validate(value)
        super
        validate_features_per_value(value)
    end

    # Make sure that we've got all of the required features for a given value.
    def validate_features_per_value(value)
        if features = self.class.value_option(self.class.value_name(value), :required_features)
            raise ArgumentError, "Provider must have features '%s' to set '%s' to '%s'" % [[features].flatten.join(", "), self.class.name, value] unless provider.satisfies?(features)
        end
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
