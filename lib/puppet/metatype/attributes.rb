require 'puppet'
require 'puppet/type'

class Puppet::Type
    class << self
        include Puppet::Util::ClassGen
        attr_reader :states
    end

    # All parameters, in the appropriate order.  The namevar comes first,
    # then the states, then the params and metaparams in the order they
    # were specified in the files.
    def self.allattrs
        # now get all of the arguments, in a specific order
        # Cache this, since it gets called so many times
        namevar = self.namevar

        order = [namevar]
        order << [self.states.collect { |state| state.name },
            self.parameters,
            self.metaparams].flatten.reject { |param|
                # we don't want our namevar in there multiple times
                param == namevar
        }

        order.flatten!

        return order
    end

    # Find the class associated with any given attribute.
    def self.attrclass(name)
        @attrclasses ||= {}

        # We cache the value, since this method gets called such a huge number
        # of times (as in, hundreds of thousands in a given run).
        unless @attrclasses.include?(name)
            @attrclasses[name] = case self.attrtype(name)
            when :state: @validstates[name]
            when :meta: @@metaparamhash[name]
            when :param: @paramhash[name]
            end
        end
        @attrclasses[name]
    end

    # What type of parameter are we dealing with? Cache the results, because
    # this method gets called so many times.
    def self.attrtype(attr)
        @attrtypes ||= {}
        unless @attrtypes.include?(attr)
            @attrtypes[attr] = case
                when @validstates.include?(attr): :state
                when @@metaparamhash.include?(attr): :meta
                when @paramhash.include?(attr): :param
                else
                    raise Puppet::DevError,
                        "Invalid attribute '%s' for class '%s'" %
                        [attr, self.name]
                end
        end

        @attrtypes[attr]
    end

    # Copy an existing class parameter.  This allows other types to avoid
    # duplicating a parameter definition, and is mostly used by subclasses
    # of the File class.
    def self.copyparam(klass, name)
        param = klass.attrclass(name)

        unless param
            raise Puppet::DevError, "Class %s has no param %s" % [klass, name]
        end
        @parameters << param
        @parameters.each { |p| @paramhash[name] = p }

        if param.isnamevar?
            @namevar = param.name
        end
    end

    # A similar function but one that yields the name, type, and class.
    # This is mainly so that setdefaults doesn't call quite so many functions.
    def self.eachattr(*ary)
        # now get all of the arguments, in a specific order
        # Cache this, since it gets called so many times

        if ary.empty?
            ary = nil
        end
        self.states.each { |state|
            yield(state, :state) if ary.nil? or ary.include?(state.name)
        }

        @parameters.each { |param|
            yield(param, :param) if ary.nil? or ary.include?(param.name)
        }

        @@metaparams.each { |param|
            yield(param, :meta) if ary.nil? or ary.include?(param.name)
        }
    end

    def self.eachmetaparam
        @@metaparams.each { |p| yield p.name }
    end

    # Create the 'ensure' class.  This is a separate method so other types
    # can easily call it and create their own 'ensure' values.
    def self.ensurable(&block)
        if block_given?
            self.newstate(:ensure, :parent => Puppet::State::Ensure, &block)
        else
            self.newstate(:ensure, :parent => Puppet::State::Ensure) do
                self.defaultvalues
            end
        end
    end

    # Should we add the 'ensure' state to this class?
    def self.ensurable?
        # If the class has all three of these methods defined, then it's
        # ensurable.
        #ens = [:create, :destroy].inject { |set, method|
        ens = [:exists?, :create, :destroy].inject { |set, method|
            set &&= self.public_method_defined?(method)
        }

        #puts "%s ensurability: %s" % [self.name, ens]

        return ens
    end

    # Is the parameter in question a meta-parameter?
    def self.metaparam?(param)
        param = symbolize(param)
        @@metaparamhash.include?(param)
    end

    # Find the metaparameter class associated with a given metaparameter name.
    def self.metaparamclass(name)
        @@metaparamhash[symbolize(name)]
    end

    def self.metaparams
        @@metaparams.collect { |param| param.name }
    end

    def self.metaparamdoc(metaparam)
        @@metaparamhash[metaparam].doc
    end

    # Create a new metaparam.  Requires a block and a name, stores it in the
    # @parameters array, and does some basic checking on it.
    def self.newmetaparam(name, &block)
        @@metaparams ||= []
        @@metaparamhash ||= {}
        name = symbolize(name)

        param = genclass(name,
            :parent => Puppet::Parameter,
            :prefix => "MetaParam",
            :hash => @@metaparamhash,
            :array => @@metaparams,
            &block
        )

        param.ismetaparameter

        return param
    end

    # Find the namevar
    def self.namevar
        unless defined? @namevar
            params = @parameters.find_all { |param|
                param.isnamevar? or param.name == :name
            }

            if params.length > 1
                raise Puppet::DevError, "Found multiple namevars for %s" % self.name
            elsif params.length == 1
                @namevar = params[0].name
            else
                raise Puppet::DevError, "No namevar for %s" % self.name
            end
        end
        @namevar
    end

    # Create a new parameter.  Requires a block and a name, stores it in the
    # @parameters array, and does some basic checking on it.
    def self.newparam(name, options = {}, &block)
        param = genclass(name,
            :parent => options[:parent] || Puppet::Parameter,
            :attributes => { :element => self },
            :block => block,
            :prefix => "Parameter",
            :array => @parameters,
            :hash => @paramhash
        )

        # These might be enabled later.
#        define_method(name) do
#            @parameters[name].value
#        end
#
#        define_method(name.to_s + "=") do |value|
#            newparam(param, value)
#        end

        if param.isnamevar?
            @namevar = param.name
        end

        return param
    end

    # Create a new state. The first parameter must be the name of the state;
    # this is how users will refer to the state when creating new instances.
    # The second parameter is a hash of options; the options are:
    # * <tt>:parent</tt>: The parent class for the state.  Defaults to Puppet::State.
    # * <tt>:retrieve</tt>: The method to call on the provider or @parent object (if
    #   the provider is not set) to retrieve the current value.
    def self.newstate(name, options = {}, &block)
        name = symbolize(name)

        # This is here for types that might still have the old method of defining
        # a parent class.
        unless options.is_a? Hash
            raise Puppet::DevError,
                "Options must be a hash, not %s" % options.inspect
        end

        if @validstates.include?(name) 
            raise Puppet::DevError, "Class %s already has a state named %s" %
                [self.name, name]
        end

        # We have to create our own, new block here because we want to define
        # an initial :retrieve method, if told to, and then eval the passed
        # block if available.
        s = genclass(name,
            :parent => options[:parent] || Puppet::State,
            :hash => @validstates
        ) do
            # If they've passed a retrieve method, then override the retrieve
            # method on the class.
            if options[:retrieve]
                define_method(:retrieve) do
                    instance_variable_set(
                        "@is", provider.send(options[:retrieve])
                    )
                end
            end

            if block
                class_eval(&block)
            end
        end

        # If it's the 'ensure' state, always put it first.
        if name == :ensure
            @states.unshift s
        else
            @states << s
        end

        if options[:event]
            s.event = options[:event]
        end

#        define_method(name) do
#            @states[name].should
#        end
#
#        define_method(name.to_s + "=") do |value|
#            newstate(name, :should => value)
#        end

        return s
    end

    def self.paramdoc(param)
        @paramhash[param].doc
    end

    # Return the parameter names
    def self.parameters
        return [] unless defined? @parameters
        @parameters.collect { |klass| klass.name }
    end

    # Find the parameter class associated with a given parameter name.
    def self.paramclass(name)
        @paramhash[name]
    end

    # Return the state class associated with a name
    def self.statebyname(name)
        @validstates[name]
    end

    def self.validattr?(name)
        name = symbolize(name)
        @validattrs ||= {}

        unless @validattrs.include?(name)
            if self.validstate?(name) or self.validparameter?(name) or self.metaparam?(name)
                @validattrs[name] = true
            else
                @validattrs[name] = false
            end
        end

        @validattrs[name]
    end

    # does the name reflect a valid state?
    def self.validstate?(name)
        name = symbolize(name)
        if @validstates.include?(name)
            return @validstates[name]
        else
            return false
        end
    end

    # Return the list of validstates
    def self.validstates
        return {} unless defined? @states

        return @validstates.keys
    end

    # does the name reflect a valid parameter?
    def self.validparameter?(name)
        unless defined? @parameters
            raise Puppet::DevError, "Class %s has not defined parameters" % self
        end
        if @paramhash.include?(name) or @@metaparamhash.include?(name)
            return true
        else
            return false
        end
    end

    # fix any namevar => param translations
    def argclean(oldhash)
        # This duplication is here because it might be a transobject.
        hash = oldhash.dup.to_hash

        if hash.include?(:parent)
            hash.delete(:parent)
        end
        namevar = self.class.namevar

        # Do a simple translation for those cases where they've passed :name
        # but that's not our namevar
        if hash.include? :name and namevar != :name
            if hash.include? namevar
                raise ArgumentError, "Cannot provide both name and %s" % namevar
            end
            hash[namevar] = hash[:name]
            hash.delete(:name)
        end

        # Make sure we have a name, one way or another
        unless hash.include? namevar
            if defined? @title and @title
                hash[namevar] = @title
            else
                raise Puppet::Error,
                    "Was not passed a namevar or title"
            end
        end

        return hash
    end

    # Is the specified parameter set?
    def attrset?(type, attr)
        case type
        when :state: return @states.include?(attr)
        when :param: return @parameters.include?(attr)
        when :meta: return @metaparams.include?(attr)
        else
            self.devfail "Invalid set type %s" % [type]
        end
    end

    # Allow an outside party to specify the 'is' value for a state.  The
    # arguments are an array because you can't use parens with 'is=' calls.
    # Most classes won't use this.
    def is=(ary)
        param, value = ary
        if param.is_a?(String)
            param = param.intern
        end
        if self.class.validstate?(param)
            unless @states.include?(param)
                self.newstate(param)
            end
            @states[param].is = value
        else
            self[param] = value
        end
    end

    # abstract accessing parameters and states, and normalize
    # access to always be symbols, not strings
    # This returns a value, not an object.  It returns the 'is'
    # value, but you can also specifically return 'is' and 'should'
    # values using 'object.is(:state)' or 'object.should(:state)'.
    def [](name)
        if name.is_a?(String)
            name = name.intern
        end

        if name == :name
            name = self.class.namevar
        end
        case self.class.attrtype(name)
        when :state
            if @states.include?(name)
                return @states[name].is
            else
                return nil
            end
        when :meta
            if @metaparams.include?(name)
                return @metaparams[name].value
            else
                if default = self.class.metaparamclass(name).default
                    return default
                else
                    return nil
                end
            end
        when :param
            if @parameters.include?(name)
                return @parameters[name].value
            else
                if default = self.class.paramclass(name).default
                    return default
                else
                    return nil
                end
            end
        else
            raise TypeError.new("Invalid parameter %s(%s)" % [name, name.inspect])
        end
    end

    # Abstract setting parameters and states, and normalize
    # access to always be symbols, not strings.  This sets the 'should'
    # value on states, and otherwise just sets the appropriate parameter.
    def []=(name,value)
        if name.is_a?(String)
            name = name.intern
        end

        if name == :name
            name = self.class.namevar
        end
        if value.nil?
            raise Puppet::Error.new("Got nil value for %s" % name)
        end

        case self.class.attrtype(name)
        when :state
            if value.is_a?(Puppet::State)
                self.debug "'%s' got handed a state for '%s'" % [self,name]
                @states[name] = value
            else
                if @states.include?(name)
                    @states[name].should = value
                else
                    # newstate returns true if it successfully created the state,
                    # false otherwise; I just don't know what to do with that
                    # fact.
                    unless newstate(name, :should => value)
                        #self.info "%s failed" % name
                    end
                end
            end
        when :meta
            self.newmetaparam(self.class.metaparamclass(name), value)
        when :param
            klass = self.class.attrclass(name)
            # if they've got a method to handle the parameter, then do it that way
            self.newparam(klass, value)
        else
            raise Puppet::Error, "Invalid parameter %s" % [name]
        end
    end

    # remove a state from the object; useful in testing or in cleanup
    # when an error has been encountered
    def delete(attr)
        case attr
        when Puppet::Type
            if @children.include?(attr)
                @children.delete(attr)
            end
        else
            if @states.has_key?(attr)
                @states.delete(attr)
            elsif @parameters.has_key?(attr)
                @parameters.delete(attr)
            elsif @metaparams.has_key?(attr)
                @metaparams.delete(attr)
            else
                raise Puppet::DevError.new("Undefined attribute '#{attr}' in #{self}")
            end
        end
    end

    # iterate across the existing states
    def eachstate
        # states() is a private method
        states().each { |state|
            yield state
        }
    end

    # retrieve the 'is' value for a specified state
    def is(state)
        if @states.include?(state)
            return @states[state].is
        else
            return nil
        end
    end

    # retrieve the 'should' value for a specified state
    def should(state)
        if @states.include?(state)
            return @states[state].should
        else
            return nil
        end
    end

    # Create a new parameter.
    def newparam(klass, value = nil)
        newattr(:param, klass, value)
    end

    # Create a new parameter or metaparameter.  We'll leave the calling
    # method to store it appropriately.
    def newmetaparam(klass, value = nil)
        newattr(:meta, klass, value)
    end

    # The base function that the others wrap.
    def newattr(type, klass, value = nil)
        # This should probably be a bit, um, different, but...
        if type == :state
            return newstate(klass)
        end
        param = klass.new
        param.parent = self

        unless value.nil?
            param.value = value
        end

        case type
        when :meta
            @metaparams[klass.name] = param
        when :param
            @parameters[klass.name] = param
        else
            self.devfail("Invalid param type %s" % type)
        end

        return param
    end

    # create a new state
    def newstate(name, hash = {})
        stateklass = nil
        if name.is_a?(Class)
            stateklass = name
            name = stateklass.name
        else
            stateklass = self.class.validstate?(name) 
            unless stateklass
                self.fail("Invalid state %s" % name)
            end
        end
        if @states.include?(name)
            hash.each { |var,value|
                @states[name].send(var.to_s + "=", value)
            }
        else
            #Puppet.warning "Creating state %s for %s" %
            #    [stateklass.name,self.name]
            begin
                hash[:parent] = self
                # make sure the state doesn't have any errors
                newstate = stateklass.new(hash)
                @states[name] = newstate
                return newstate
            rescue Puppet::Error => detail
                # the state failed, so just ignore it
                self.warning "State %s failed: %s" %
                    [name, detail]
                return false
            rescue Puppet::DevError => detail
                # the state failed, so just ignore it
                self.err "State %s failed: %s" %
                    [name, detail]
                return false
            rescue => detail
                # the state failed, so just ignore it
                self.err "State %s failed: %s (%s)" %
                    [name, detail, detail.class]
                return false
            end
        end
    end

    # return the value of a parameter
    def parameter(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @parameters[name].value
    end

    # Is the named state defined?
    def statedefined?(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @states.include?(name)
    end

    # return an actual type by name; to return the value, use 'inst[name]'
    # FIXME this method should go away
    def state(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @states[name]
    end

#    def set(name, value)
#        send(name.to_s + "=", value)
#    end
#
#    def get(name)
#        send(name)
#    end

    # For any parameters or states that have defaults and have not yet been
    # set, set them now.
    def setdefaults(*ary)
        self.class.eachattr(*ary) { |klass, type|
            # not many attributes will have defaults defined, so we short-circuit
            # those away
            next unless klass.method_defined?(:default)
            next if self.attrset?(type, klass.name)

            obj = self.newattr(type, klass)
            value = obj.default
            unless value.nil?
                #self.debug "defaulting %s to %s" % [obj.name, obj.default]
                obj.value = value
            else
                #self.debug "No default for %s" % obj.name
                # "obj" is a Parameter.
                self.delete(obj.name)
            end
        }

    end

    # Convert our object to a hash.  This just includes states.
    def to_hash
        rethash = {}
    
        [@parameters, @metaparams, @states].each do |hash|
            hash.each do |name, obj|
                rethash[name] = obj.value
            end
        end

        rethash
    end

    # Meta-parameter methods:  These methods deal with the results
    # of specifying metaparameters

    private

    def states
        #debug "%s has %s states" % [self,@states.length]
        tmpstates = []
        self.class.states.each { |state|
            if @states.include?(state.name)
                tmpstates.push(@states[state.name])
            end
        }
        unless tmpstates.length == @states.length
            self.devfail(
                "Something went very wrong with tmpstates creation"
            )
        end
        return tmpstates
    end
end

# $Id$
