require 'puppet/util/methodhelper'
require 'puppet/util/log_paths'
require 'puppet/util/logging'
require 'puppet/util/docs'
require 'puppet/util/cacher'

class Puppet::Parameter
    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::LogPaths
    include Puppet::Util::Logging
    include Puppet::Util::MethodHelper
    include Puppet::Util::Cacher

    # A collection of values and regexes, used for specifying
    # what values are allowed in a given parameter.
    class ValueCollection
        class Value
            attr_reader :name, :options, :event
            attr_accessor :block, :call, :method, :required_features

            # Add an alias for this value.
            def alias(name)
                @aliases << convert(name)
            end

            # Return all aliases.
            def aliases
                @aliases.dup
            end

            # Store the event that our value generates, if it does so.
            def event=(value)
                @event = convert(value)
            end

            def initialize(name)
                if name.is_a?(Regexp)
                    @name = name
                else
                    # Convert to a string and then a symbol, so things like true/false
                    # still show up as symbols.
                    @name = convert(name)
                end

                @aliases = []

                @call = :instead
            end

            # Does a provided value match our value?
            def match?(value)
                if regex?
                    return true if name =~ value.to_s
                else
                    return true if name == convert(value)
                    return @aliases.include?(convert(value))
                end
            end

            # Is our value a regex?
            def regex?
                @name.is_a?(Regexp)
            end

            private

            # A standard way of converting all of our values, so we're always
            # comparing apples to apples.
            def convert(value)
                if value == ''
                    # We can't intern an empty string, yay.
                    value
                else
                    value.to_s.to_sym
                end
            end
        end

        def aliasvalue(name, other)
            other = other.to_sym
            unless value = match?(other)
                raise Puppet::DevError, "Cannot alias nonexistent value %s" % other
            end

            value.alias(name)
        end

        # Return a doc string for all of the values in this parameter/property.
        def doc
            unless defined?(@doc)
                @doc = ""
                unless values.empty?
                    @doc += "  Valid values are "
                    @doc += @strings.collect do |value|
                        if aliases = value.aliases and ! aliases.empty?
                            "``%s`` (also called ``%s``)" % [value.name, aliases.join(", ")]
                        else
                            "``%s``" % value.name
                        end
                    end.join(", ") + "."
                end

                unless regexes.empty?
                    @doc += "  Values can match ``" + regexes.join("``, ``") + "``."
                end
            end

            @doc
        end

        # Does this collection contain any value definitions?
        def empty?
            @values.empty?
        end

        def initialize
            # We often look values up by name, so a hash makes more sense.
            @values = {}

            # However, we want to retain the ability to match values in order,
            # but we always prefer directly equality (i.e., strings) over regex matches.
            @regexes = []
            @strings = []
        end

        # Can we match a given value?
        def match?(test_value)
            # First look for normal values
            if value = @strings.find { |v| v.match?(test_value) }
                return value
            end

            # Then look for a regex match
            @regexes.find { |v| v.match?(test_value) }
        end

        # If the specified value is allowed, then munge appropriately.
        def munge(value)
            return value if empty?

            if instance = match?(value)
                if instance.regex?
                    return value
                else
                    return instance.name
                end
            else
                return value
            end
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
        def newvalue(name, options = {}, &block)
            value = Value.new(name)
            @values[value.name] = value
            if value.regex?
                @regexes << value
            else
                @strings << value
            end

            options.each { |opt, arg| value.send(opt.to_s + "=", arg) }
            if block_given?
                value.block = block
            else
                value.call = options[:call] || :none
            end

            if block_given? and ! value.regex?
                value.method ||= "set_" + value.name.to_s
            end

            value
        end

        # Define one or more new values for our parameter.
        def newvalues(*names)
            names.each { |name| newvalue(name) }
        end

        def regexes
            @regexes.collect { |r| r.name.inspect }
        end

        # Verify that the passed value is valid.
        def validate(value)
            return if empty?

            unless @values.detect { |name, v| v.match?(value) }
                str = "Invalid value %s. " % [value.inspect]

                unless values.empty?
                    str += "Valid values are %s. " % values.join(", ")
                end

                unless regexes.empty?
                    str += "Valid values match %s." % regexes.join(", ")
                end

                raise ArgumentError, str
            end
        end

        # Return a single value instance.
        def value(name)
            @values[name]
        end

        # Return the list of valid values.
        def values
            @strings.collect { |s| s.name }
        end
    end

    class << self
        include Puppet::Util
        include Puppet::Util::Docs
        attr_reader :validater, :munger, :name, :default, :required_features, :value_collection
        attr_accessor :metaparam

        # Define the default value for a given parameter or parameter.  This
        # means that 'nil' is an invalid default value.  This defines
        # the 'default' instance method.
        def defaultto(value = nil, &block)
            if block
                define_method(:default, &block)
            else
                if value.nil?
                    raise Puppet::DevError,
                        "Either a default value or block must be provided"
                end
                define_method(:default) do value end
            end
        end

        # Return a documentation string.  If there are valid values,
        # then tack them onto the string.
        def doc
            @doc ||= ""

            unless defined? @addeddocvals
                @doc += value_collection.doc

                if f = self.required_features
                    @doc += "  Requires features %s." % f.flatten.collect { |f| f.to_s }.join(" ")
                end
                @addeddocvals = true
            end

            @doc
        end

        def nodefault
            if public_method_defined? :default
                undef_method :default
            end
        end

        # Store documentation for this parameter.
        def desc(str)
            @doc = str
        end

        def initvars
            @value_collection = ValueCollection.new
        end

        # This is how we munge the value.  Basically, this is our
        # opportunity to convert the value from one form into another.
        def munge(&block)
            # I need to wrap the unsafe version in begin/rescue parameterments,
            # but if I directly call the block then it gets bound to the
            # class's context, not the instance's, thus the two methods,
            # instead of just one.
            define_method(:unsafe_munge, &block)
        end

        # Does the parameter supports reverse munge?
        # This will be called when something wants to access the parameter
        # in a canonical form different to what the storage form is.
        def unmunge(&block)
            define_method(:unmunge, &block)
        end

        # Optionaly convert the value to a canonical form so that it will
        # be found in hashes, etc.  Mostly useful for namevars.
        def to_canonicalize(&block)
            metaclass = (class << self; self; end)
            metaclass.send(:define_method,:canonicalize,&block)
        end

        # Mark whether we're the namevar.
        def isnamevar
            @isnamevar = true
            @required = true
        end

        # Is this parameter the namevar?  Defaults to false.
        def isnamevar?
            if defined? @isnamevar
                return @isnamevar
            else
                return false
            end
        end

        # This parameter is required.
        def isrequired
            @required = true
        end

        # Specify features that are required for this parameter to work.
        def required_features=(*args)
            @required_features = args.flatten.collect { |a| a.to_s.downcase.intern }
        end

        # Is this parameter required?  Defaults to false.
        def required?
            if defined? @required
                return @required
            else
                return false
            end
        end

        # Verify that we got a good value
        def validate(&block)
            define_method(:unsafe_validate, &block)
        end

        # Define a new value for our parameter.
        def newvalues(*names)
            @value_collection.newvalues(*names)
        end

        def aliasvalue(name, other)
            @value_collection.aliasvalue(name, other)
        end
    end

    # Just a simple method to proxy instance methods to class methods
    def self.proxymethods(*values)
        values.each { |val|
            define_method(val) do
                self.class.send(val)
            end
        }
    end

    # And then define one of these proxies for each method in our
    # ParamHandler class.
    proxymethods("required?", "isnamevar?")

    attr_accessor :resource
    # LAK 2007-05-09: Keep the @parent around for backward compatibility.
    attr_accessor :parent

    [:line, :file, :version].each do |param|
        define_method(param) do
            resource.send(param)
        end
    end

    def devfail(msg)
        self.fail(Puppet::DevError, msg)
    end

    def expirer
        resource.catalog
    end

    def fail(*args)
        type = nil
        if args[0].is_a?(Class)
            type = args.shift
        else
            type = Puppet::Error
        end

        error = type.new(args.join(" "))

        if defined? @resource and @resource and @resource.line
            error.line = @resource.line
        end

        if defined? @resource and @resource and @resource.file
            error.file = @resource.file
        end

        raise error
    end

    # Basic parameter initialization.
    def initialize(options = {})
        options = symbolize_options(options)
        if resource = options[:resource]
            self.resource = resource
            options.delete(:resource)
        else
            raise Puppet::DevError, "No resource set for %s" % self.class.name
        end

        set_options(options)
    end

    # Log a message using the resource's log level.
    def log(msg)
        unless @resource[:loglevel]
            self.devfail "Parent %s has no loglevel" %
                @resource.name
        end
        Puppet::Util::Log.create(
            :level => @resource[:loglevel],
            :message => msg,
            :source => self
        )
    end

    # Is this parameter a metaparam?
    def metaparam?
        self.class.metaparam
    end

    # each parameter class must define the name() method, and parameter
    # instances do not change that name this implicitly means that a given
    # object can only have one parameter instance of a given parameter
    # class
    def name
        return self.class.name
    end

    # for testing whether we should actually do anything
    def noop
        unless defined? @noop
            @noop = false
        end
        tmp = @noop || self.resource.noop || Puppet[:noop] || false
        #debug "noop is %s" % tmp
        return tmp
    end

    # return the full path to us, for logging and rollback; not currently
    # used
    def pathbuilder
        if defined? @resource and @resource
            return [@resource.pathbuilder, self.name]
        else
            return [self.name]
        end
    end

    # If the specified value is allowed, then munge appropriately.
    # If the developer uses a 'munge' hook, this method will get overridden.
    def unsafe_munge(value)
        self.class.value_collection.munge(value)
    end

    # no unmunge by default
    def unmunge(value)
        value
    end

    # Assume the value is already in canonical form by default
    def self.canonicalize(value)
        value
    end

    def canonicalize(value)
        self.class.canonicalize(value)
    end

    # A wrapper around our munging that makes sure we raise useful exceptions.
    def munge(value)
        begin
            ret = unsafe_munge(canonicalize(value))
        rescue Puppet::Error => detail
            Puppet.debug "Reraising %s" % detail
            raise
        rescue => detail
            raise Puppet::DevError, "Munging failed for value %s in class %s: %s" % [value.inspect, self.name, detail], detail.backtrace
        end
        ret
    end

    # Verify that the passed value is valid.
    # If the developer uses a 'validate' hook, this method will get overridden.
    def unsafe_validate(value)
        self.class.value_collection.validate(value)
    end

    # A protected validation method that only ever raises useful exceptions.
    def validate(value)
        begin
            unsafe_validate(value)
        rescue ArgumentError => detail
            fail detail.to_s
        rescue Puppet::Error, TypeError
            raise
        rescue => detail
            raise Puppet::DevError, "Validate method failed for class %s: %s" % [self.name, detail], detail.backtrace
        end
    end

    def remove
        @resource = nil
    end

    def value
        unmunge(@value)
    end

    # Store the value provided.  All of the checking should possibly be
    # late-binding (e.g., users might not exist when the value is assigned
    # but might when it is asked for).
    def value=(value)
        validate(value)

        @value = munge(value)
    end

    # Retrieve the resource's provider.  Some types don't have providers, in which
    # case we return the resource object itself.
    def provider
        @resource.provider
    end

    # The properties need to return tags so that logs correctly collect them.
    def tags
        unless defined? @tags
            @tags = []
            # This might not be true in testing
            if @resource.respond_to? :tags
                @tags = @resource.tags
            end
            @tags << self.name.to_s
        end
        @tags
    end

    def to_s
        s = "Parameter(%s)" % self.name
    end
end
