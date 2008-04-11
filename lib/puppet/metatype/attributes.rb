require 'puppet'
require 'puppet/type'

class Puppet::Type
    class << self
        include Puppet::Util::ClassGen
        include Puppet::Util::Warnings
        attr_reader :properties
    end

    def self.states
        warnonce "The states method is deprecated; use properties"
        properties()
    end

    # All parameters, in the appropriate order.  The namevar comes first,
    # then the properties, then the params and metaparams in the order they
    # were specified in the files.
    def self.allattrs
        # now get all of the arguments, in a specific order
        # Cache this, since it gets called so many times
        namevar = self.namevar

        order = [namevar]
        if self.parameters.include?(:provider)
            order << :provider
        end
        order << [self.properties.collect { |property| property.name },
            self.parameters - [:provider],
            self.metaparams].flatten.reject { |param|
                # we don't want our namevar in there multiple times
                param == namevar
        }

        order.flatten!

        return order
    end

    # Retrieve an attribute alias, if there is one.
    def self.attr_alias(param)
        @attr_aliases[symbolize(param)]
    end

    # Create an alias to an existing attribute.  This will cause the aliased
    # attribute to be valid when setting and retrieving values on the instance.
    def self.set_attr_alias(hash)
        hash.each do |new, old|
            @attr_aliases[symbolize(new)] = symbolize(old)
        end
    end

    # Find the class associated with any given attribute.
    def self.attrclass(name)
        @attrclasses ||= {}

        # We cache the value, since this method gets called such a huge number
        # of times (as in, hundreds of thousands in a given run).
        unless @attrclasses.include?(name)
            @attrclasses[name] = case self.attrtype(name)
            when :property: @validproperties[name]
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
                when @validproperties.include?(attr): :property
                when @paramhash.include?(attr): :param
                when @@metaparamhash.include?(attr): :meta
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

    # A similar function but one that yields the class and type.
    # This is mainly so that setdefaults doesn't call quite so many functions.
    def self.eachattr(*ary)
        if ary.empty?
            ary = nil
        end

        # We have to do this in a specific order, so that defaults are
        # created in that order (e.g., providers should be set up before
        # anything else).
        allattrs.each do |name|
            next unless ary.nil? or ary.include?(name)
            if obj = @properties.find { |p| p.name == name }
                yield obj, :property
            elsif obj = @parameters.find { |p| p.name == name }
                yield obj, :param
            elsif obj = @@metaparams.find { |p| p.name == name }
                yield obj, :meta
            else
                raise Puppet::DevError, "Could not find parameter %s" % name
            end
        end
    end

    def self.eachmetaparam
        @@metaparams.each { |p| yield p.name }
    end

    # Create the 'ensure' class.  This is a separate method so other types
    # can easily call it and create their own 'ensure' values.
    def self.ensurable(&block)
        if block_given?
            self.newproperty(:ensure, :parent => Puppet::Property::Ensure, &block)
        else
            self.newproperty(:ensure, :parent => Puppet::Property::Ensure) do
                self.defaultvalues
            end
        end
    end

    # Should we add the 'ensure' property to this class?
    def self.ensurable?
        # If the class has all three of these methods defined, then it's
        # ensurable.
        ens = [:exists?, :create, :destroy].inject { |set, method|
            set &&= self.public_method_defined?(method)
        }

        return ens
    end
    
    # Deal with any options passed into parameters.
    def self.handle_param_options(name, options)
        # If it's a boolean parameter, create a method to test the value easily
        if options[:boolean]
            define_method(name.to_s + "?") do
                val = self[name]
                if val == :true or val == true
                    return true
                end
            end
        end
        
        # If this param handles relationships, store that information
    end

    # Is the parameter in question a meta-parameter?
    def self.metaparam?(param)
        @@metaparamhash.include?(symbolize(param))
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
    def self.newmetaparam(name, options = {}, &block)
        @@metaparams ||= []
        @@metaparamhash ||= {}
        name = symbolize(name)

        param = genclass(name,
            :parent => options[:parent] || Puppet::Parameter,
            :prefix => "MetaParam",
            :hash => @@metaparamhash,
            :array => @@metaparams,
            :attributes => options[:attributes],
            &block
        )

        # Grr.
        if options[:required_features]
            param.required_features = options[:required_features]
        end
        
        handle_param_options(name, options)

        param.metaparam = true

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
        options[:attributes] ||= {}
        param = genclass(name,
            :parent => options[:parent] || Puppet::Parameter,
            :attributes => options[:attributes],
            :block => block,
            :prefix => "Parameter",
            :array => @parameters,
            :hash => @paramhash
        )
        
        handle_param_options(name, options)

        # Grr.
        if options[:required_features]
            param.required_features = options[:required_features]
        end

        param.isnamevar if options[:namevar]

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

    def self.newstate(name, options = {}, &block)
        Puppet.warning "newstate() has been deprecrated; use newproperty(%s)" %
            name
        newproperty(name, options, &block)
    end

    # Create a new property. The first parameter must be the name of the property;
    # this is how users will refer to the property when creating new instances.
    # The second parameter is a hash of options; the options are:
    # * <tt>:parent</tt>: The parent class for the property.  Defaults to Puppet::Property.
    # * <tt>:retrieve</tt>: The method to call on the provider or @parent object (if
    #   the provider is not set) to retrieve the current value.
    def self.newproperty(name, options = {}, &block)
        name = symbolize(name)

        # This is here for types that might still have the old method of defining
        # a parent class.
        unless options.is_a? Hash
            raise Puppet::DevError,
                "Options must be a hash, not %s" % options.inspect
        end

        if @validproperties.include?(name) 
            raise Puppet::DevError, "Class %s already has a property named %s" %
                [self.name, name]
        end

        if parent = options[:parent]
            options.delete(:parent)
        else
            parent = Puppet::Property
        end

        # We have to create our own, new block here because we want to define
        # an initial :retrieve method, if told to, and then eval the passed
        # block if available.
        prop = genclass(name, :parent => parent, :hash => @validproperties, :attributes => options) do
            # If they've passed a retrieve method, then override the retrieve
            # method on the class.
            if options[:retrieve]
                define_method(:retrieve) do
                    provider.send(options[:retrieve])
                end
            end

            if block
                class_eval(&block)
            end
        end

        # If it's the 'ensure' property, always put it first.
        if name == :ensure
            @properties.unshift prop
        else
            @properties << prop
        end

#        define_method(name) do
#            @parameters[name].should
#        end
#
#        define_method(name.to_s + "=") do |value|
#            newproperty(name, :should => value)
#        end

        return prop
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

    # Return the property class associated with a name
    def self.propertybyname(name)
        @validproperties[name]
    end

    def self.validattr?(name)
        name = symbolize(name)
        return true if name == :name
        @validattrs ||= {}

        unless @validattrs.include?(name)
            if self.validproperty?(name) or self.validparameter?(name) or self.metaparam?(name)
                @validattrs[name] = true
            else
                @validattrs[name] = false
            end
        end

        @validattrs[name]
    end

    # does the name reflect a valid property?
    def self.validproperty?(name)
        name = symbolize(name)
        if @validproperties.include?(name)
            return @validproperties[name]
        else
            return false
        end
    end

    # Return the list of validproperties
    def self.validproperties
        return {} unless defined? @parameters

        return @validproperties.keys
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

        if hash.include?(:resource)
            hash.delete(:resource)
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
                raise Puppet::Error, "Was not passed a namevar or title"
            end
        end

        return hash
    end

    # Return either the attribute alias or the attribute.
    def attr_alias(name)
        name = symbolize(name)
        if synonym = self.class.attr_alias(name)
            return synonym
        else
            return name
        end
    end
    
    # Are we deleting this resource?
    def deleting?
        obj = @parameters[:ensure] and obj.should == :absent
    end

    # Create a new property if it is valid but doesn't exist
    # Returns: true if a new parameter was added, false otherwise
    def add_property_parameter(prop_name)
        if self.class.validproperty?(prop_name) && !@parameters[prop_name]
            self.newattr(prop_name)
            return true
        end
        return false
    end
    
    # abstract accessing parameters and properties, and normalize
    # access to always be symbols, not strings
    # This returns a value, not an object.  It returns the 'is'
    # value, but you can also specifically return 'is' and 'should'
    # values using 'object.is(:property)' or 'object.should(:property)'.
    def [](name)
        name = attr_alias(name)

        unless self.class.validattr?(name)
            raise TypeError.new("Invalid parameter %s(%s)" % [name, name.inspect])
        end

        if name == :name
            name = self.class.namevar
        end

        if obj = @parameters[name]
            # Note that if this is a property, then the value is the "should" value,
            # not the current value.
            obj.value
        else
            return nil
        end
    end

    # Abstract setting parameters and properties, and normalize
    # access to always be symbols, not strings.  This sets the 'should'
    # value on properties, and otherwise just sets the appropriate parameter.
    def []=(name,value)
        name = attr_alias(name)

        unless self.class.validattr?(name)
            raise TypeError.new("Invalid parameter %s" % [name])
        end

        if name == :name
            name = self.class.namevar
        end
        if value.nil?
            raise Puppet::Error.new("Got nil value for %s" % name)
        end

        if obj = @parameters[name]
            obj.value = value
            return nil
        else
            self.newattr(name, :value => value)
        end

        nil
    end

    # remove a property from the object; useful in testing or in cleanup
    # when an error has been encountered
    def delete(attr)
        attr = symbolize(attr)
        if @parameters.has_key?(attr)
            @parameters.delete(attr)
        else
            raise Puppet::DevError.new("Undefined attribute '#{attr}' in #{self}")
        end
    end

    # iterate across the existing properties
    def eachproperty
        # properties() is a private method
        properties().each { |property|
            yield property
        }
    end

    # retrieve the 'should' value for a specified property
    def should(name)
        name = attr_alias(name)
        if prop = @parameters[name] and prop.is_a?(Puppet::Property)
            return prop.should
        else
            return nil
        end
    end

    # Create the actual attribute instance.  Requires either the attribute
    # name or class as the first argument, then an optional hash of
    # attributes to set during initialization.
    def newattr(name, options = {})
        if name.is_a?(Class)
            klass = name
            name = klass.name
        end

        unless klass = self.class.attrclass(name)
            raise Puppet::Error, "Resource type %s does not support parameter %s" % [self.class.name, name]
        end

        if @parameters.include?(name)
            raise Puppet::Error, "Parameter '%s' is already defined in %s" %
                [name, self.ref]
        end

        if provider and ! provider.class.supports_parameter?(klass)
            missing = klass.required_features.find_all { |f| ! provider.class.feature?(f) }
            info "Provider %s does not support features %s; not managing attribute %s" % [provider.class.name, missing.join(", "), name]
            return nil
        end

        # Add resource information at creation time, so it's available
        # during validation.
        options[:resource] = self
        begin
            # make sure the parameter doesn't have any errors
            return @parameters[name] = klass.new(options)
        rescue => detail
            error = Puppet::Error.new("Parameter %s failed: %s" %
                [name, detail])
            error.set_backtrace(detail.backtrace)
            raise error
        end
    end

    # return the value of a parameter
    def parameter(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @parameters[name].value
    end

    # Is the named property defined?
    def propertydefined?(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @parameters.include?(name)
    end

    # return an actual type by name; to return the value, use 'inst[name]'
    # FIXME this method should go away
    def property(name)
        if obj = @parameters[symbolize(name)] and obj.is_a?(Puppet::Property)
            return obj
        else
            return nil
        end
    end

#    def set(name, value)
#        send(name.to_s + "=", value)
#    end
#
#    def get(name)
#        send(name)
#    end

    # For any parameters or properties that have defaults and have not yet been
    # set, set them now.  This method can be handed a list of attributes,
    # and if so it will only set defaults for those attributes.
    def setdefaults(*ary)
        #self.class.eachattr(*ary) { |klass, type|
        self.class.eachattr(*ary) { |klass, type|
            # not many attributes will have defaults defined, so we short-circuit
            # those away
            next unless klass.method_defined?(:default)
            next if @parameters[klass.name]

            next unless obj = self.newattr(klass)

            # We have to check for nil values, not "truth", so we allow defaults
            # to false.
            value = obj.default and ! value.nil?
            if ! value.nil?
                obj.value = value
            else
                @parameters.delete(obj.name)
            end
        }
    end

    # Convert our object to a hash.  This just includes properties.
    def to_hash
        rethash = {}
    
        @parameters.each do |name, obj|
            rethash[name] = obj.value
        end

        rethash
    end

    # Return a specific value for an attribute.
    def value(name)
        name = attr_alias(name)

        if obj = @parameters[name] and obj.respond_to?(:value)
            return obj.value
        else
            return nil
        end
    end

    # Meta-parameter methods:  These methods deal with the results
    # of specifying metaparameters

    private

    # Return all of the property objects, in the order specified in the
    # class.
    def properties
        #debug "%s has %s properties" % [self,@parameters.length]
        props = self.class.properties.collect { |prop|
            @parameters[prop.name]
        }.find_all { |p|
            ! p.nil?
        }.each do |prop|
            unless prop.is_a?(Puppet::Property)
                raise Puppet::DevError, "got a non-property %s(%s)" %
                    [prop.class, prop.class.name]
            end
        end

        props
    end
end

