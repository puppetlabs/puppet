require 'puppet/util/methodhelper'
require 'puppet/util/log_paths'
require 'puppet/util/logging'
require 'puppet/util/docs'

class Puppet::Parameter
    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::LogPaths
    include Puppet::Util::Logging
    include Puppet::Util::MethodHelper
    class << self
        include Puppet::Util
        include Puppet::Util::Docs
        attr_reader :validater, :munger, :name, :default, :required_features
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
                unless values.empty?
                    if @aliasvalues.empty?
                        @doc += "  Valid values are ``" +
                            values.join("``, ``") + "``."
                    else
                        @doc += "  Valid values are "

                        @doc += values.collect do |value|
                            ary = @aliasvalues.find do |name, val|
                                val == value
                            end
                            if ary
                                "``%s`` (also called ``%s``)" % [value, ary[0]]
                            else
                                "``#{value}``"
                            end
                        end.join(", ") + "."
                    end
                end

                if defined? @parameterregexes and ! @parameterregexes.empty?
                    regs = @parameterregexes
                    if @parameterregexes.is_a? Hash
                        regs = @parameterregexes.keys
                    end
                    unless regs.empty?
                        @doc += "  Values can also match ``" +
                            regs.collect { |r| r.inspect }.join("``, ``") + "``."
                    end
                end

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
            @parametervalues = []
            @aliasvalues = {}
            @parameterregexes = []
        end

        # This is how we munge the value.  Basically, this is our
        # opportunity to convert the value from one form into another.
        def munge(&block)
            # I need to wrap the unsafe version in begin/rescue parameterments,
            # but if I directly call the block then it gets bound to the
            # class's context, not the instance's, thus the two methods,
            # instead of just one.
            define_method(:unsafe_munge, &block)

            define_method(:munge) do |*args|
                begin
                    ret = unsafe_munge(*args)
                rescue Puppet::Error => detail
                    Puppet.debug "Reraising %s" % detail
                    raise
                rescue => detail
                    raise Puppet::DevError, "Munging failed for value %s in class %s: %s" %
                        [args.inspect, self.name, detail], detail.backtrace
                end

                if self.shadow
                    self.shadow.munge(*args)
                end
                ret
            end
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
            #@validater = block
            define_method(:unsafe_validate, &block)

            define_method(:validate) do |*args|
                begin
                    unsafe_validate(*args)
                rescue ArgumentError, Puppet::Error, TypeError
                    raise
                rescue => detail
                    raise Puppet::DevError,
                        "Validate method failed for class %s: %s" %
                        [self.name, detail], detail.backtrace
                end
            end
        end

        # Does the value match any of our regexes?
        def match?(value)
            value = value.to_s unless value.is_a? String
            @parameterregexes.find { |r|
                r = r[0] if r.is_a? Array # Properties use a hash here
                r =~ value
            }
        end

        # Define a new value for our parameter.
        def newvalues(*names)
            names.each { |name|
                name = name.intern if name.is_a? String

                case name
                when Symbol
                    if @parametervalues.include?(name)
                        Puppet.warning "%s already has a value for %s" %
                            [name, name]
                    end
                    @parametervalues << name
                when Regexp
                    if @parameterregexes.include?(name)
                        Puppet.warning "%s already has a value for %s" %
                            [name, name]
                    end
                    @parameterregexes << name
                else
                    raise ArgumentError, "Invalid value %s of type %s" %
                        [name, name.class]
                end
            }
        end

        def aliasvalue(name, other)
            other = symbolize(other)
            unless @parametervalues.include?(other)
                raise Puppet::DevError,
                    "Cannot alias nonexistent value %s" % other
            end

            @aliasvalues[name] = other
        end

        def alias(name)
            @aliasvalues[name]
        end

        def regexes
            return @parameterregexes.dup
        end

        def required_features=(*args)
            @required_features = args.flatten.collect { |a| a.to_s.downcase.intern }
        end

        # Return the list of valid values.
        def values
            #[@aliasvalues.keys, @parametervalues.keys].flatten
            if @parametervalues.is_a? Array
                return @parametervalues.dup
            elsif @parametervalues.is_a? Hash
                return @parametervalues.keys
            else
                return []
            end
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
    attr_reader :shadow

    def devfail(msg)
        self.fail(Puppet::DevError, msg)
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

        if ! self.metaparam? and klass = Puppet::Type.metaparamclass(self.class.name)
            setup_shadow(klass)
        end

        set_options(options)
    end

    # Log a message using the resource's log level.
    def log(msg)
        unless @resource[:loglevel]
            p @resource
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
    munge do |value|
        if self.class.values.empty? and self.class.regexes.empty?
            # This parameter isn't using defined values to do its work.
            return value
        end

        # We convert to a string and then a symbol so that things like
        # booleans work as we expect.
        intern = value.to_s.intern

        # If it's a valid value, always return it as a symbol.
        if self.class.values.include?(intern)
            retval = intern
        elsif other = self.class.alias(intern)
            retval = other
        elsif ary = self.class.match?(value)
            retval = value
        else
            # If it passed the validation but is not a registered value,
            # we just return it as is.
            retval = value
        end

        retval
    end

    # Verify that the passed value is valid.
    validate do |value|
        vals = self.class.values
        regs = self.class.regexes

        # this is true on properties
        regs = regs.keys if regs.is_a?(Hash)

        # This parameter isn't using defined values to do its work.
        return if vals.empty? and regs.empty?

        newval = value
        newval = value.to_s.intern unless value.is_a?(Symbol)

        name = newval

        unless vals.include?(newval) or name = self.class.alias(newval) or name = self.class.match?(value) # We match the string, not the symbol
            str = "Invalid '%s' value %s. " %
                [self.class.name, value.inspect]

            unless vals.empty?
                str += "Valid values are %s. " % vals.join(", ")
            end

            unless regs.empty?
                str += "Valid values match %s." % regs.collect { |r|
                    r.to_s
                }.join(", ")
            end

            raise ArgumentError, str
        end

        # Now check for features.
        name = name[0] if name.is_a?(Array) # This is true for regexes.
        validate_features_per_value(name) if is_a?(Puppet::Property)
    end

    def remove
        @resource = nil
        @shadow = nil
    end

    attr_reader :value

    # Store the value provided.  All of the checking should possibly be
    # late-binding (e.g., users might not exist when the value is assigned
    # but might when it is asked for).
    def value=(value)
        if respond_to?(:validate)
            validate(value)
        end

        if respond_to?(:munge)
            value = munge(value)
        end
        @value = value
    end

    def inspect
        s = "Parameter(%s = %s" % [self.name, self.value || "nil"]
        if defined? @resource
            s += ", @resource = %s)" % @resource
        else
            s += ")"
        end
    end

    # Retrieve the resource's provider.  Some types don't have providers, in which
    # case we return the resource object itself.
    def provider
        @resource.provider || @resource
    end

    # If there's a shadowing metaparam, instantiate it now.
    # This allows us to create a property or parameter with the
    # same name as a metaparameter, and the metaparam will only be
    # stored as a shadow.
    def setup_shadow(klass)
        @shadow = klass.new(:resource => self.resource)
    end

    def to_s
        s = "Parameter(%s)" % self.name
    end

    # Make sure that we've got all of the required features for a given value.
    def validate_features_per_value(value)
        if features = self.class.value_option(value, :required_features)
            raise ArgumentError, "Provider must have features '%s' to set '%s' to '%s'" % [features, self.class.name, value] unless provider.satisfies?(features)
        end
    end
end

