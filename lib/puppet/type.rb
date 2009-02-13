require 'puppet'
require 'puppet/util/log'
require 'puppet/util/metric'
require 'puppet/property'
require 'puppet/parameter'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/metatype/manager'
require 'puppet/util/errors'
require 'puppet/util/log_paths'
require 'puppet/util/logging'
require 'puppet/resource_reference'
require 'puppet/file_collection/lookup'

# see the bottom of the file for the rest of the inclusions

module Puppet
class Type
    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::LogPaths
    include Puppet::Util::Logging
    include Puppet::FileCollection::Lookup

    ###############################
    # Code related to resource type attributes.
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

    public

    ###############################
    # Code related to the closure-like behaviour of the resource classes.
    attr_writer :implicit

    # Is this type's name isomorphic with the object?  That is, if the
    # name conflicts, does it necessarily mean that the objects conflict?
    # Defaults to true.
    def self.isomorphic?
        if defined? @isomorphic
            return @isomorphic
        else
            return true
        end
    end

    def implicit?
        if defined? @implicit and @implicit
            return true
        else
            return false
        end
    end

    def isomorphic?
        self.class.isomorphic?
    end

    # is the instance a managed instance?  A 'yes' here means that
    # the instance was created from the language, vs. being created
    # in order resolve other questions, such as finding a package
    # in a list
    def managed?
        # Once an object is managed, it always stays managed; but an object
        # that is listed as unmanaged might become managed later in the process,
        # so we have to check that every time
        if defined? @managed and @managed
            return @managed
        else
            @managed = false
            properties.each { |property|
                s = property.should
                if s and ! property.class.unmanaged
                    @managed = true
                    break
                end
            }
            return @managed
        end
    end

    ###############################
    # Code related to the container behaviour.
    def self.depthfirst?
        if defined? @depthfirst
            return @depthfirst
        else
            return false
        end
    end
    
    def depthfirst?
        self.class.depthfirst?
    end

    # Add a hook for testing for recursion.
    def parentof?(child)
        if (self == child)
            debug "parent is equal to child"
            return true
        elsif defined? @parent and @parent.parentof?(child)
            debug "My parent is parent of child"
            return true
        else
            return false
        end
    end

    # Remove an object.  The argument determines whether the object's
    # subscriptions get eliminated, too.
    def remove(rmdeps = true)
        # This is hackish (mmm, cut and paste), but it works for now, and it's
        # better than warnings.
        @parameters.each do |name, obj|
            obj.remove
        end
        @parameters.clear
        self.class.delete(self)

        @parent = nil

        # Remove the reference to the provider.
        if self.provider
            @provider.clear
            @provider = nil
        end
    end

    ###############################
    # Code related to evaluating the resources.

    # This method is responsible for collecting property changes we always
    # descend into the children before we evaluate our current properties.
    # This returns any changes resulting from testing, thus 'collect' rather
    # than 'each'.
    def evaluate
        if self.provider.is_a?(Puppet::Provider)
            unless provider.class.suitable?
                raise Puppet::Error, "Provider %s is not functional on this platform" % provider.class.name
            end
        end
        #Puppet.err "Evaluating %s" % self.path.join(":")
        unless defined? @evalcount
            self.err "No evalcount defined on '%s' of type '%s'" %
                [self.title,self.class]
            @evalcount = 0
        end
        @evalcount += 1

        # this only operates on properties, not properties + children
        # it's important that we call retrieve() on the type instance,
        # not directly on the property, because it allows the type to override
        # the method, like pfile does
        currentvalues = self.retrieve

        changes = propertychanges(currentvalues).flatten

        # now record how many changes we've resulted in
        if changes.length > 0
            self.debug "%s change(s)" %
                [changes.length]
        end

        # If we're in noop mode, we don't want to store the checked time,
        # because it will result in the resource not getting scheduled if
        # someone were to apply the catalog in non-noop mode.
        # We're going to go ahead and record that we checked if there were
        # no changes, since it's unlikely it will affect the scheduling.
        noop = noop?
        if ! noop or (noop && changes.length == 0)
            self.cache(:checked, Time.now)
        end
        return changes.flatten
    end

    # Flush the provider, if it supports it.  This is called by the
    # transaction.
    def flush
        if self.provider and self.provider.respond_to?(:flush)
            self.provider.flush
        end
    end

    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more,
    # it's really only used for testing
    def insync?(is)
        insync = true
        
        if property = @parameters[:ensure]
            unless is.include? property
               raise Puppet::DevError,
                        "The is value is not in the is array for '%s'" %
                        [property.name]
            end
            ensureis = is[property]           
            if property.insync?(ensureis) and property.should == :absent
                return true
            end
        end

        properties.each { |property|
            unless is.include? property
               raise Puppet::DevError,
                        "The is value is not in the is array for '%s'" %
                        [property.name]
            end

            propis = is[property]
            unless property.insync?(propis)
                property.debug("Not in sync: %s vs %s" %
                    [propis.inspect, property.should.inspect])
                insync = false
            #else
            #    property.debug("In sync")
            end
        }

        #self.debug("%s sync status is %s" % [self,insync])
        return insync
    end
        
    # retrieve the current value of all contained properties
    def retrieve
        return currentpropvalues
    end
    
    # Get a hash of the current properties.  Returns a hash with
    # the actual property instance as the key and the current value
    # as the, um, value.
    def currentpropvalues
        # It's important to use the 'properties' method here, as it follows the order
        # in which they're defined in the class.  It also guarantees that 'ensure'
        # is the first property, which is important for skipping 'retrieve' on
        # all the properties if the resource is absent.
        ensure_state = false
        return properties().inject({}) do | prophash, property|
            if property.name == :ensure
                ensure_state = property.retrieve
                prophash[property] = ensure_state
            else
                if ensure_state == :absent
                    prophash[property] = :absent
                else
                    prophash[property] = property.retrieve
                end
            end
            prophash
        end
    end

    # Are we running in noop mode?
    def noop?
        if defined?(@noop)
            @noop
        else
            Puppet[:noop]
        end
    end

    def noop
        noop?
    end
     
    # Retrieve the changes associated with all of the properties.
    def propertychanges(currentvalues)
        # If we are changing the existence of the object, then none of
        # the other properties matter.
        changes = []
        ensureparam = @parameters[:ensure]

        # This allows resource types to have 'ensure' be a parameter, which allows them to
        # just pass the parameter on to other generated resources.
        ensureparam = nil unless ensureparam.is_a?(Puppet::Property)
        if ensureparam && !currentvalues.include?(ensureparam)
            raise Puppet::DevError, "Parameter ensure defined but missing from current values"
        end

        if ensureparam and ! ensureparam.insync?(currentvalues[ensureparam])
            changes << Puppet::Transaction::Change.new(ensureparam, currentvalues[ensureparam])
        # Else, if the 'ensure' property is correctly absent, then do
        # nothing
        elsif ensureparam and currentvalues[ensureparam] == :absent
            return []
        else
            changes = properties().find_all { |property|
                currentvalues[property] ||= :absent
                ! property.insync?(currentvalues[property])
            }.collect { |property|
                Puppet::Transaction::Change.new(property, currentvalues[property])
            }
        end

        if Puppet[:debug] and changes.length > 0
            self.debug("Changing " + changes.collect { |ch| ch.property.name }.join(","))
        end

        changes
    end

    ###############################
    # Code related to managing resource instances.
    require 'puppet/transportable'

    # Make 'new' private, so people have to use create instead.
    class << self
        private :new
    end

    # retrieve a named instance of the current type
    def self.[](name)
        @objects[name] || @aliases[name]
    end

    # add an instance by name to the class list of instances
    def self.[]=(name,object)
        newobj = nil
        if object.is_a?(Puppet::Type)
            newobj = object
        else
            raise Puppet::DevError, "must pass a Puppet::Type object"
        end

        if exobj = @objects[name] and self.isomorphic?
            msg = "Object '%s[%s]' already exists" %
                [newobj.class.name, name]

            if exobj.file and exobj.line
                msg += ("in file %s at line %s" %
                    [object.file, object.line])
            end
            if object.file and object.line
                msg += ("and cannot be redefined in file %s at line %s" %
                    [object.file, object.line])
            end
            error = Puppet::Error.new(msg)
            raise error
        else
            #Puppet.info("adding %s of type %s to class list" %
            #    [name,object.class])
            @objects[name] = newobj
        end
    end

    # Create an alias.  We keep these in a separate hash so that we don't encounter
    # the objects multiple times when iterating over them.
    def self.alias(name, obj)
        if @objects.include?(name)
            unless @objects[name] == obj
                raise Puppet::Error.new(
                    "Cannot create alias %s: object already exists" %
                    [name]
                )
            end
        end

        if @aliases.include?(name)
            unless @aliases[name] == obj
                raise Puppet::Error.new(
                    "Object %s already has alias %s" %
                    [@aliases[name].name, name]
                )
            end
        end

        @aliases[name] = obj
    end

    # remove all of the instances of a single type
    def self.clear
        if defined? @objects
            @objects.each do |name, obj|
                obj.remove(true)
            end
            @objects.clear
        end
        if defined? @aliases
            @aliases.clear
        end
    end

    # Force users to call this, so that we can merge objects if
    # necessary.
    def self.create(args)
        # Don't modify the original hash; instead, create a duplicate and modify it.
        # We have to dup and use the ! so that it stays a TransObject if it is
        # one.
        hash = args.dup
        symbolizehash!(hash)

        # If we're the base class, then pass the info on appropriately
        if self == Puppet::Type
            type = nil
            if hash.is_a? Puppet::TransObject
                type = hash.type
            else
                # If we're using the type to determine object type, then delete it
                if type = hash[:type]
                    hash.delete(:type)
                end
            end

            # If they've specified a type and called on the base, then
            # delegate to the subclass.
            if type
                if typeklass = self.type(type)
                    return typeklass.create(hash)
                else
                    raise Puppet::Error, "Unknown type %s" % type
                end
            else
                raise Puppet::Error, "No type found for %s" % hash.inspect
            end
        end

        # Handle this new object being implicit
        implicit = hash[:implicit] || false
        if hash.include?(:implicit)
            hash.delete(:implicit)
        end

        name = nil
        unless hash.is_a? Puppet::TransObject
            hash = self.hash2trans(hash)
        end

        # XXX This will have to change when transobjects change to using titles
        title = hash.name

        # if the object already exists
        if self.isomorphic? and retobj = self[title]
            # if only one of our objects is implicit, then it's easy to see
            # who wins -- the non-implicit one.
            if retobj.implicit? and ! implicit
                Puppet.notice "Removing implicit %s" % retobj.title
                # Remove all of the objects, but do not remove their subscriptions.
                retobj.remove(false)

                # now pass through and create the new object
            elsif implicit
                Puppet.debug "Ignoring implicit %s[%s]" % [self.name, title]
                return nil
            else
                raise Puppet::Error, "%s is already being managed" % retobj.ref
            end
        end

        # create it anew
        # if there's a failure, destroy the object if it got that far, but raise
        # the error.
        begin
            obj = new(hash)
        rescue => detail
            Puppet.err "Could not create %s: %s" % [title, detail.to_s]
            if obj
                obj.remove(true)
            elsif obj = self[title]
                obj.remove(true)
            end
            raise
        end

        if implicit
            obj.implicit = true
        end

        # Store the object by title
        self[obj.title] = obj

        return obj
    end

    # remove a specified object
    def self.delete(resource)
        return unless defined? @objects
        if @objects.include?(resource.title)
            @objects.delete(resource.title)
        end
        if @aliases.include?(resource.title)
            @aliases.delete(resource.title)
        end
        if @aliases.has_value?(resource)
            names = []
            @aliases.each do |name, otherres|
                if otherres == resource
                    names << name
                end
            end
            names.each { |name| @aliases.delete(name) }
        end
    end

    # iterate across each of the type's instances
    def self.each
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end

    # does the type have an object with the given name?
    def self.has_key?(name)
        return @objects.has_key?(name)
    end

    # Convert a hash to a TransObject.
    def self.hash2trans(hash)
        title = nil
        if hash.include? :title
            title = hash[:title]
            hash.delete(:title)
        elsif hash.include? self.namevar
            title = hash[self.namevar]
            hash.delete(self.namevar)

            if hash.include? :name
                raise ArgumentError, "Cannot provide both name and %s to %s" %
                    [self.namevar, self.name]
            end
        elsif hash[:name]
            title = hash[:name]
            hash.delete :name
        end

        if catalog = hash[:catalog]
            hash.delete(:catalog)
        end

        raise(Puppet::Error, "You must specify a title for objects of type %s" % self.to_s) unless title

        if hash.include? :type
            unless self.validattr? :type
                hash.delete :type
            end
        end

        # okay, now make a transobject out of hash
        begin
            trans = Puppet::TransObject.new(title, self.name.to_s)
            trans.catalog = catalog if catalog
            hash.each { |param, value|
                trans[param] = value
            }
        rescue => detail
            raise Puppet::Error, "Could not create %s: %s" %
                [name, detail]
        end

        return trans
    end

    # Retrieve all known instances.  Either requires providers or must be overridden.
    def self.instances
        unless defined?(@providers) and ! @providers.empty?
            raise Puppet::DevError, "%s has no providers and has not overridden 'instances'" % self.name
        end

        # Put the default provider first, then the rest of the suitable providers.
        provider_instances = {}
        providers_by_source.collect do |provider|
            provider.instances.collect do |instance|
                # First try to get the resource if it already exists
                # Skip instances that map to a managed resource with a different provider
                next if resource = self[instance.name] and resource.provider.class != instance.class

                # We always want to use the "first" provider instance we find, unless the resource
                # is already managed and has a different provider set
                if other = provider_instances[instance.name]
                    Puppet.warning "%s %s found in both %s and %s; skipping the %s version" %
                        [self.name.to_s.capitalize, instance.name, other.class.name, instance.class.name, instance.class.name]
                    next
                end
                provider_instances[instance.name] = instance

                if resource
                    resource.provider = instance
                    resource
                else
                    create(:name => instance.name, :provider => instance, :check => :all)
                end
            end
        end.flatten.compact
    end

    # Return a list of one suitable provider per source, with the default provider first.
    def self.providers_by_source
        # Put the default provider first, then the rest of the suitable providers.
        sources = []
        [defaultprovider, suitableprovider].flatten.uniq.collect do |provider|
            next if sources.include?(provider.source)

            sources << provider.source
            provider
        end.compact
    end

    # Create the path for logging and such.
    def pathbuilder
        if p = parent
            [p.pathbuilder, self.ref].flatten
        else
            [self.ref]
        end
    end

    ###############################
    # Add all of the meta parameters.
    newmetaparam(:noop) do
        desc "Boolean flag indicating whether work should actually
            be done."
            
        newvalues(:true, :false)
        munge do |value|
            case value
            when true, :true, "true": @resource.noop = true
            when false, :false, "false": @resource.noop = false
            end
        end
    end

    newmetaparam(:schedule) do
        desc "On what schedule the object should be managed.  You must create a
            schedule object, and then reference the name of that object to use
            that for your schedule::

                schedule { daily:
                    period => daily,
                    range => \"2-4\"
                }

                exec { \"/usr/bin/apt-get update\":
                    schedule => daily
                }

            The creation of the schedule object does not need to appear in the
            configuration before objects that use it."
    end

    newmetaparam(:check) do
        desc "Propertys which should have their values retrieved
            but which should not actually be modified.  This is currently used
            internally, but will eventually be used for querying, so that you
            could specify that you wanted to check the install state of all
            packages, and then query the Puppet client daemon to get reports
            on all packages."

        munge do |args|
            # If they've specified all, collect all known properties
            if args == :all
                args = @resource.class.properties.find_all do |property|
                    # Only get properties supported by our provider
                    if @resource.provider
                        @resource.provider.class.supports_parameter?(property)
                    else
                        true
                    end
                end.collect do |property|
                    property.name
                end
            end

            unless args.is_a?(Array)
                args = [args]
            end

            unless defined? @resource
                self.devfail "No parent for %s, %s?" %
                    [self.class, self.name]
            end

            args.each { |property|
                unless property.is_a?(Symbol)
                    property = property.intern
                end
                next if @resource.propertydefined?(property)

                unless propertyklass = @resource.class.validproperty?(property)
                    if @resource.class.validattr?(property)
                        next
                    else
                        raise Puppet::Error, "%s is not a valid attribute for %s" %
                            [property, self.class.name]
                    end
                end
                next unless propertyklass.checkable?
                @resource.newattr(property)
            }
        end
    end
    
    # We've got four relationship metaparameters, so this method is used
    # to reduce code duplication between them.
    def munge_relationship(param, values)
        # We need to support values passed in as an array or as a
        # resource reference.
        result = []
        
        # 'values' could be an array or a reference.  If it's an array,
        # it could be an array of references or an array of arrays.
        if values.is_a?(Puppet::Type)
            result << [values.class.name, values.title]
        else
            unless values.is_a?(Array)
                devfail "Relationships must be resource references"
            end
            if values[0].is_a?(String) or values[0].is_a?(Symbol)
                # we're a type/title array reference
                values[0] = symbolize(values[0])
                result << values
            else
                # we're an array of stuff
                values.each do |value|
                    if value.is_a?(Puppet::Type)
                        result << [value.class.name, value.title]
                    elsif value.is_a?(Array)
                        value[0] = symbolize(value[0])
                        result << value
                    else
                        devfail "Invalid relationship %s" % value.inspect
                    end
                end
            end
        end
        
        if existing = self[param]
            result = existing + result
        end
        
        result
    end

    newmetaparam(:loglevel) do
        desc "Sets the level that information will be logged.
             The log levels have the biggest impact when logs are sent to
             syslog (which is currently the default)."
        defaultto :notice

        newvalues(*Puppet::Util::Log.levels)
        newvalues(:verbose)

        munge do |loglevel|
            val = super(loglevel)
            if val == :verbose
                val = :info 
            end        
            val
        end
    end

    newmetaparam(:alias) do
        desc "Creates an alias for the object.  Puppet uses this internally when you
            provide a symbolic name::
            
                file { sshdconfig:
                    path => $operatingsystem ? {
                        solaris => \"/usr/local/etc/ssh/sshd_config\",
                        default => \"/etc/ssh/sshd_config\"
                    },
                    source => \"...\"
                }

                service { sshd:
                    subscribe => file[sshdconfig]
                }

            When you use this feature, the parser sets ``sshdconfig`` as the name,
            and the library sets that as an alias for the file so the dependency
            lookup for ``sshd`` works.  You can use this parameter yourself,
            but note that only the library can use these aliases; for instance,
            the following code will not work::

                file { \"/etc/ssh/sshd_config\":
                    owner => root,
                    group => root,
                    alias => sshdconfig
                }

                file { sshdconfig:
                    mode => 644
                }

            There's no way here for the Puppet parser to know that these two stanzas
            should be affecting the same file.

            See the `LanguageTutorial language tutorial`:trac: for more information.
            
            "

        munge do |aliases|
            unless aliases.is_a?(Array)
                aliases = [aliases]
            end

            raise(ArgumentError, "Cannot add aliases without a catalog") unless @resource.catalog

            aliases.each do |other|
                if obj = @resource.catalog.resource(@resource.class.name, other)
                    unless obj.object_id == @resource.object_id
                        self.fail("%s can not create alias %s: object already exists" % [@resource.title, other])
                    end
                    next
                end

                # LAK:FIXME Old-school, add the alias to the class.
                @resource.class.alias(other, @resource)

                # Newschool, add it to the catalog.
                @resource.catalog.alias(@resource, other)
            end
        end
    end

    newmetaparam(:tag) do
        desc "Add the specified tags to the associated resource.  While all resources
            are automatically tagged with as much information as possible
            (e.g., each class and definition containing the resource), it can
            be useful to add your own tags to a given resource.

            Tags are currently useful for things like applying a subset of a
            host's configuration::
                
                puppetd --test --tags mytag

            This way, when you're testing a configuration you can run just the
            portion you're testing."

        munge do |tags|
            tags = [tags] unless tags.is_a? Array

            tags.each do |tag|
                @resource.tag(tag)
            end
        end
    end
    
    class RelationshipMetaparam < Puppet::Parameter
        class << self
            attr_accessor :direction, :events, :callback, :subclasses
        end
        
        @subclasses = []
        
        def self.inherited(sub)
            @subclasses << sub
        end
        
        def munge(rels)
            @resource.munge_relationship(self.class.name, rels)
        end

        def validate_relationship
            @value.each do |value|
                unless @resource.catalog.resource(*value)
                    description = self.class.direction == :in ? "dependency" : "dependent"
                    fail Puppet::Error, "Could not find %s %s[%s] for %s" % 
                        [description, value[0].to_s.capitalize, value[1], resource.ref]
                end
            end
        end
        
        # Create edges from each of our relationships.    :in
        # relationships are specified by the event-receivers, and :out
        # relationships are specified by the event generator.  This
        # way 'source' and 'target' are consistent terms in both edges
        # and events -- that is, an event targets edges whose source matches
        # the event's source.  The direction of the relationship determines
        # which resource is applied first and which resource is considered
        # to be the event generator.
        def to_edges
            @value.collect do |value|
                # we just have a name and a type, and we need to convert it
                # to an object...
                tname, name = value
                reference = Puppet::ResourceReference.new(tname, name)
                
                # Either of the two retrieval attempts could have returned
                # nil.
                unless object = reference.resolve
                    self.fail "Could not retrieve dependency '%s' of %s" % [reference, @resource.ref]
                end

                # Are we requiring them, or vice versa?  See the method docs
                # for futher info on this.
                if self.class.direction == :in
                    source = object
                    target = @resource
                else
                    source = @resource
                    target = object
                end

                if method = self.class.callback
                    subargs = {
                        :event => self.class.events,
                        :callback => method
                    }
                    self.debug("subscribes to %s" % [object.ref])
                else
                    # If there's no callback, there's no point in even adding
                    # a label.
                    subargs = nil
                    self.debug("requires %s" % [object.ref])
                end
                
                rel = Puppet::Relationship.new(source, target, subargs)
            end
        end
    end
    
    def self.relationship_params
        RelationshipMetaparam.subclasses
    end


    # Note that the order in which the relationships params is defined
    # matters.  The labelled params (notify and subcribe) must be later,
    # so that if both params are used, those ones win.  It's a hackish
    # solution, but it works.

    newmetaparam(:require, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :NONE}) do
        desc "One or more objects that this object depends on.
            This is used purely for guaranteeing that changes to required objects
            happen before the dependent object.  For instance::
            
                # Create the destination directory before you copy things down
                file { \"/usr/local/scripts\":
                    ensure => directory
                }

                file { \"/usr/local/scripts/myscript\":
                    source => \"puppet://server/module/myscript\",
                    mode => 755,
                    require => File[\"/usr/local/scripts\"]
                }

            Multiple dependencies can be specified by providing a comma-seperated list
            of resources, enclosed in square brackets::

                require => [ File[\"/usr/local\"], File[\"/usr/local/scripts\"] ]

            Note that Puppet will autorequire everything that it can, and
            there are hooks in place so that it's easy for resources to add new
            ways to autorequire objects, so if you think Puppet could be
            smarter here, let us know.

            In fact, the above code was redundant -- Puppet will autorequire
            any parent directories that are being managed; it will
            automatically realize that the parent directory should be created
            before the script is pulled down.
            
            Currently, exec resources will autorequire their CWD (if it is
            specified) plus any fully qualified paths that appear in the
            command.   For instance, if you had an ``exec`` command that ran
            the ``myscript`` mentioned above, the above code that pulls the
            file down would be automatically listed as a requirement to the
            ``exec`` code, so that you would always be running againts the
            most recent version.
            "
    end

    newmetaparam(:subscribe, :parent => RelationshipMetaparam, :attributes => {:direction => :in, :events => :ALL_EVENTS, :callback => :refresh}) do
        desc "One or more objects that this object depends on.  Changes in the
            subscribed to objects result in the dependent objects being
            refreshed (e.g., a service will get restarted).  For instance::
            
                class nagios {
                    file { \"/etc/nagios/nagios.conf\":
                        source => \"puppet://server/module/nagios.conf\",
                        alias => nagconf # just to make things easier for me
                    }
                    service { nagios:
                        running => true,
                        subscribe => File[nagconf]
                    }
                }
	 		
            Currently the ``exec``, ``mount`` and ``service`` type support
            refreshing.
            "
    end

    newmetaparam(:before, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :NONE}) do
        desc %{This parameter is the opposite of **require** -- it guarantees
            that the specified object is applied later than the specifying
            object::

                file { "/var/nagios/configuration":
                    source  => "...",
                    recurse => true,
                    before => Exec["nagios-rebuid"]
                }

                exec { "nagios-rebuild":
                    command => "/usr/bin/make",
                    cwd => "/var/nagios/configuration"
                }
            
            This will make sure all of the files are up to date before the
            make command is run.}
    end
    
    newmetaparam(:notify, :parent => RelationshipMetaparam, :attributes => {:direction => :out, :events => :ALL_EVENTS, :callback => :refresh}) do
        desc %{This parameter is the opposite of **subscribe** -- it sends events
            to the specified object::

                file { "/etc/sshd_config":
                    source => "....",
                    notify => Service[sshd]
                }

                service { sshd:
                    ensure => running
                }
            
            This will restart the sshd service if the sshd config file changes.}
    end

    ###############################
    # All of the provider plumbing for the resource types.
    require 'puppet/provider'
    require 'puppet/util/provider_features'

    # Add the feature handling module.
    extend Puppet::Util::ProviderFeatures

    attr_reader :provider

    # the Type class attribute accessors
    class << self
        attr_accessor :providerloader
        attr_writer :defaultprovider
    end

    # Find the default provider.
    def self.defaultprovider
        unless defined? @defaultprovider and @defaultprovider
            suitable = suitableprovider()

            # Find which providers are a default for this system.
            defaults = suitable.find_all { |provider| provider.default? }

            # If we don't have any default we use suitable providers
            defaults = suitable if defaults.empty?
            max = defaults.collect { |provider| provider.defaultnum }.max
            defaults = defaults.find_all { |provider| provider.defaultnum == max }

            retval = nil
            if defaults.length > 1
                Puppet.warning(
                    "Found multiple default providers for %s: %s; using %s" %
                    [self.name, defaults.collect { |i| i.name.to_s }.join(", "),
                        defaults[0].name]
                )
                retval = defaults.shift
            elsif defaults.length == 1
                retval = defaults.shift
            else
                raise Puppet::DevError, "Could not find a default provider for %s" %
                    self.name
            end

            @defaultprovider = retval
        end

        return @defaultprovider
    end

    # Convert a hash, as provided by, um, a provider, into an instance of self.
    def self.hash2obj(hash)
        obj = nil
        
        namevar = self.namevar
        unless hash.include?(namevar) and hash[namevar]
            raise Puppet::DevError, "Hash was not passed with namevar"
        end

        # if the obj already exists with that name...
        if obj = self[hash[namevar]]
            # We're assuming here that objects with the same name
            # are the same object, which *should* be the case, assuming
            # we've set up our naming stuff correctly everywhere.

            # Mark found objects as present
            hash.each { |param, value|
                if property = obj.property(param)
                elsif val = obj[param]
                    obj[param] = val
                else
                    # There is a value on disk, but it should go away
                    obj[param] = :absent
                end
            }
        else
            # create a new obj, since no existing one seems to
            # match
            obj = self.create(namevar => hash[namevar])

            # We can't just pass the hash in at object creation time,
            # because it sets the should value, not the is value.
            hash.delete(namevar)
            hash.each { |param, value|
                obj[param] = value unless obj.add_property_parameter(param)
            }
        end

        return obj
    end

    # Retrieve a provider by name.
    def self.provider(name)
        name = Puppet::Util.symbolize(name)

        # If we don't have it yet, try loading it.
        unless @providers.has_key?(name)
            @providerloader.load(name)
        end
        return @providers[name]
    end

    # Just list all of the providers.
    def self.providers
        @providers.keys
    end

    def self.validprovider?(name)
        name = Puppet::Util.symbolize(name)

        return (@providers.has_key?(name) && @providers[name].suitable?)
    end

    # Create a new provider of a type.  This method must be called
    # directly on the type that it's implementing.
    def self.provide(name, options = {}, &block)
        name = Puppet::Util.symbolize(name)

        if obj = @providers[name]
            Puppet.debug "Reloading %s %s provider" % [name, self.name]
            unprovide(name)
        end

        parent = if pname = options[:parent]
            options.delete(:parent)
            if pname.is_a? Class
                pname
            else
                if provider = self.provider(pname)
                    provider
                else
                    raise Puppet::DevError,
                        "Could not find parent provider %s of %s" %
                            [pname, name]
                end
            end
        else
            Puppet::Provider
        end

        options[:resource_type] ||= self

        self.providify

        provider = genclass(name,
            :parent => parent,
            :hash => @providers,
            :prefix => "Provider",
            :block => block,
            :include => feature_module,
            :extend => feature_module,
            :attributes => options
        )

        return provider
    end

    # Make sure we have a :provider parameter defined.  Only gets called if there
    # are providers.
    def self.providify
        return if @paramhash.has_key? :provider

        newparam(:provider) do
            desc "The specific backend for #{self.name.to_s} to use. You will
                seldom need to specify this -- Puppet will usually discover the
                appropriate provider for your platform."

            # This is so we can refer back to the type to get a list of
            # providers for documentation.
            class << self
                attr_accessor :parenttype
            end

            # We need to add documentation for each provider.
            def self.doc
                @doc + "  Available providers are:\n\n" + parenttype().providers.sort { |a,b|
                    a.to_s <=> b.to_s
                }.collect { |i|
                    "* **%s**: %s" % [i, parenttype().provider(i).doc]
                }.join("\n")
            end

            defaultto {
                @resource.class.defaultprovider.name
            }

            validate do |provider_class|
                provider_class = provider_class[0] if provider_class.is_a? Array
                if provider_class.is_a?(Puppet::Provider)
                    provider_class = provider_class.class.name
                end

                unless provider = @resource.class.provider(provider_class)
                    raise ArgumentError, "Invalid %s provider '%s'" % [@resource.class.name, provider_class]
                end
            end

            munge do |provider|
                provider = provider[0] if provider.is_a? Array
                if provider.is_a? String
                    provider = provider.intern
                end
                @resource.provider = provider

                if provider.is_a?(Puppet::Provider)
                    provider.class.name
                else
                    provider
                end
            end
        end.parenttype = self
    end

    def self.unprovide(name)
        if @providers.has_key? name
            rmclass(name,
                :hash => @providers,
                :prefix => "Provider"
            )
            if @defaultprovider and @defaultprovider.name == name
                @defaultprovider = nil
            end
        end
    end

    # Return an array of all of the suitable providers.
    def self.suitableprovider
        if @providers.empty?
            providerloader.loadall
        end
        @providers.find_all { |name, provider|
            provider.suitable?
        }.collect { |name, provider|
            provider
        }.reject { |p| p.name == :fake } # For testing
    end

    def provider=(name)
        if name.is_a?(Puppet::Provider)
            @provider = name
            @provider.resource = self
        elsif klass = self.class.provider(name)
            @provider = klass.new(self)
        else
            raise ArgumentError, "Could not find %s provider of %s" %
                [name, self.class.name]
        end
    end

    ###############################
    # All of the relationship code.

    # Specify a block for generating a list of objects to autorequire.  This
    # makes it so that you don't have to manually specify things that you clearly
    # require.
    def self.autorequire(name, &block)
        @autorequires ||= {}
        @autorequires[name] = block
    end

    # Yield each of those autorequires in turn, yo.
    def self.eachautorequire
        @autorequires ||= {}
        @autorequires.each { |type, block|
            yield(type, block)
        }
    end

    # Figure out of there are any objects we can automatically add as
    # dependencies.
    def autorequire
        reqs = []
        self.class.eachautorequire { |type, block|
            # Ignore any types we can't find, although that would be a bit odd.
            next unless typeobj = Puppet.type(type)

            # Retrieve the list of names from the block.
            next unless list = self.instance_eval(&block)
            unless list.is_a?(Array)
                list = [list]
            end

            # Collect the current prereqs
            list.each { |dep|
                obj = nil
                # Support them passing objects directly, to save some effort.
                unless dep.is_a? Puppet::Type
                    # Skip autorequires that we aren't managing
                    unless dep = typeobj[dep]
                        next
                    end
                end
                
                reqs << Puppet::Relationship.new(dep, self)
            }
        }
        
        return reqs
    end

    # Build the dependencies associated with an individual object.
    def builddepends
        # Handle the requires
        self.class.relationship_params.collect do |klass|
            if param = @parameters[klass.name]
                param.to_edges
            end
        end.flatten.reject { |r| r.nil? }
    end
    
    # Does this resource have a relationship with the other?  We have to
    # check each object for both directions of relationship.
    def requires?(other)
        them = [other.class.name, other.title]
        me = [self.class.name, self.title]
        self.class.relationship_params.each do |param|
            case param.direction
            when :in: return true if v = self[param.name] and v.include?(them)
            when :out: return true if v = other[param.name] and v.include?(me)
            end
        end
        return false
    end

    # we've received an event
    # we only support local events right now, so we can pass actual
    # objects around, including the transaction object
    # the assumption here is that container objects will pass received
    # methods on to contained objects
    # i.e., we don't trigger our children, our refresh() method calls
    # refresh() on our children
    def trigger(event, source)
        trans = event.transaction
        if @callbacks.include?(source)
            [:ALL_EVENTS, event.event].each { |eventname|
                if method = @callbacks[source][eventname]
                    if trans.triggered?(self, method) > 0
                        next
                    end
                    if self.respond_to?(method)
                        self.send(method)
                    end

                    trans.triggered(self, method)
                end
            }
        end
    end
    
    # Unsubscribe from a given object, possibly with a specific event.
    def unsubscribe(object, event = nil)
        # First look through our own relationship params
        [:require, :subscribe].each do |param|
            if values = self[param]
                newvals = values.reject { |d|
                    d == [object.class.name, object.title]
                }
                if newvals.length != values.length
                    self.delete(param)
                    self[param] = newvals
                end
            end
        end
    end

    ###############################
    # All of the scheduling code.

    # Look up the schedule and set it appropriately.  This is done after
    # the instantiation phase, so that the schedule can be anywhere in the
    # file.
    def schedule
        unless defined? @schedule
            if name = self[:schedule]
                if sched = Puppet.type(:schedule)[name]
                    @schedule = sched
                else
                    self.fail "Could not find schedule %s" % name
                end
            else
                @schedule = nil
            end
        end
        @schedule
    end

    # Check whether we are scheduled to run right now or not.
    def scheduled?
        return true if Puppet[:ignoreschedules]
        return true unless schedule = self.schedule

        # We use 'checked' here instead of 'synced' because otherwise we'll
        # end up checking most resources most times, because they will generally
        # have been synced a long time ago (e.g., a file only gets updated
        # once a month on the server and its schedule is daily; the last sync time
        # will have been a month ago, so we'd end up checking every run).
        return schedule.match?(self.cached(:checked).to_i)
    end

    ###############################
    # All of the tagging code.
    attr_reader :tags

    # Add a new tag.
    def tag(tag)
        tag = tag.intern if tag.is_a? String
        unless @tags.include? tag
            @tags << tag
        end
    end

    # Define the initial list of tags.
    def tags=(list)
        list = [list] unless list.is_a? Array

        @tags = list.collect do |t|
            case t
            when String: t.intern
            when Symbol: t
            else
                self.warning "Ignoring tag %s of type %s" % [tag.inspect, tag.class]
            end
        end

        @tags << self.class.name unless @tags.include?(self.class.name)
    end

    # Figure out of any of the specified tags apply to this object.  This is an
    # OR operation.
    def tagged?(tags)
        tags = [tags] unless tags.is_a? Array

        tags = tags.collect { |t| t.intern }

        return tags.find { |tag| @tags.include? tag }
    end

    # Types (which map to resources in the languages) are entirely composed of
    # attribute value pairs.  Generally, Puppet calls any of these things an
    # 'attribute', but these attributes always take one of three specific
    # forms:  parameters, metaparams, or properties.

    # In naming methods, I have tried to consistently name the method so
    # that it is clear whether it operates on all attributes (thus has 'attr' in
    # the method name, or whether it operates on a specific type of attributes.
    attr_writer :title
    attr_writer :noop

    include Enumerable
    
    # class methods dealing with Type management

    public

    # the Type class attribute accessors
    class << self
        attr_reader :name
        attr_accessor :self_refresh
        include Enumerable, Puppet::Util::ClassGen
        include Puppet::MetaType::Manager

        include Puppet::Util
        include Puppet::Util::Logging
    end

    # all of the variables that must be initialized for each subclass
    def self.initvars
        # all of the instances of this class
        @objects = Hash.new
        @aliases = Hash.new

        @providers = Hash.new
        @defaults = {}

        unless defined? @parameters
            @parameters = []
        end

        @validproperties = {}
        @properties = []
        @parameters = []
        @paramhash = {}

        @attr_aliases = {}

        @paramdoc = Hash.new { |hash,key|
          if key.is_a?(String)
            key = key.intern
          end
          if hash.include?(key)
            hash[key]
          else
            "Param Documentation for %s not found" % key
          end
        }

        unless defined? @doc
            @doc = ""
        end

    end

    def self.to_s
        if defined? @name
            "Puppet::Type::" + @name.to_s.capitalize
        else
            super
        end
    end

    # Create a block to validate that our object is set up entirely.  This will
    # be run before the object is operated on.
    def self.validate(&block)
        define_method(:validate, &block)
        #@validate = block
    end

    # The catalog that this resource is stored in.
    attr_accessor :catalog
    
    # create a log at specified level
    def log(msg)
        Puppet::Util::Log.create(
            :level => @parameters[:loglevel].value,
            :message => msg,
            :source => self
        )
    end


    # instance methods related to instance intrinsics
    # e.g., initialize() and name()

    public

    def initvars
        @evalcount = 0
        @tags = []

        # callbacks are per object and event
        @callbacks = Hash.new { |chash, key|
            chash[key] = {}
        }

        # properties and parameters are treated equivalently from the outside:
        # as name-value pairs (using [] and []=)
        # internally, however, parameters are merely a hash, while properties
        # point to Property objects
        # further, the lists of valid properties and parameters are defined
        # at the class level
        unless defined? @parameters
            @parameters = {}
        end

        # keeping stats for the total number of changes, and how many were
        # completely sync'ed
        # this isn't really sufficient either, because it adds lots of special
        # cases such as failed changes
        # it also doesn't distinguish between changes from the current transaction
        # vs. changes over the process lifetime
        @totalchanges = 0
        @syncedchanges = 0
        @failedchanges = 0

        @inited = true
    end

    # initialize the type instance
    def initialize(hash)
        unless defined? @inited
            self.initvars
        end
        namevar = self.class.namevar

        orighash = hash

        # If we got passed a transportable object, we just pull a bunch of info
        # directly from it.  This is the main object instantiation mechanism.
        if hash.is_a?(Puppet::TransObject)
            # XXX This will need to change when transobjects change to titles.
            self.title = hash.name

            #self[:name] = hash[:name]
            [:file, :line, :tags, :catalog].each { |getter|
                if hash.respond_to?(getter)
                    setter = getter.to_s + "="
                    if val = hash.send(getter)
                        self.send(setter, val)
                    end
                end
            }

            hash = hash.to_hash
        else
            if hash[:title]
                @title = hash[:title]
                hash.delete(:title)
            end
        end

        # Before anything else, set our parent if it was included
        if hash.include?(:parent)
            @parent = hash[:parent]
            hash.delete(:parent)
        end

        # Munge up the namevar stuff so we only have one value.
        hash = self.argclean(hash)

        # Let's do the name first, because some things need to happen once
        # we have the name but before anything else

        attrs = self.class.allattrs

        if hash.include?(namevar)
            #self.send(namevar.to_s + "=", hash[namevar])
            self[namevar] = hash[namevar]
            hash.delete(namevar)
            if attrs.include?(namevar)
                attrs.delete(namevar)
            else
                self.devfail "My namevar isn't a valid attribute...?"
            end
        else
            self.devfail "I was not passed a namevar"
        end

        # If the name and title differ, set up an alias
        if self.name != self.title
            if obj = self.class[self.name] 
                if self.class.isomorphic?
                    raise Puppet::Error, "%s already exists with name %s" %
                        [obj.title, self.name]
                end
            else
                self.class.alias(self.name, self)
            end
        end

        if hash.include?(:provider)
            self[:provider] = hash[:provider]
            hash.delete(:provider)
        else
            setdefaults(:provider)
        end

        # This is all of our attributes except the namevar.
        attrs.each { |attr|
            if hash.include?(attr)
                begin
                    self[attr] = hash[attr]
                rescue ArgumentError, Puppet::Error, TypeError
                    raise
                rescue => detail
                    error = Puppet::DevError.new( "Could not set %s on %s: %s" % [attr, self.class.name, detail])
                    error.set_backtrace(detail.backtrace)
                    raise error
                end
                hash.delete attr
            end
        }
        
        # Set all default values.
        self.setdefaults

        if hash.length > 0
            self.debug hash.inspect
            self.fail("Class %s does not accept argument(s) %s" %
                [self.class.name, hash.keys.join(" ")])
        end

        if self.respond_to?(:validate)
            self.validate
        end
    end

    # Set up all of our autorequires.
    def finish
        # Scheduling has to be done when the whole config is instantiated, so
        # that file order doesn't matter in finding them.
        self.schedule

        # Make sure all of our relationships are valid.  Again, must be done
        # when the entire catalog is instantiated.
        self.class.relationship_params.collect do |klass|
            if param = @parameters[klass.name]
                param.validate_relationship
            end
        end.flatten.reject { |r| r.nil? }
    end

    # Return a cached value
    def cached(name)
        Puppet::Util::Storage.cache(self)[name]
        #@cache[name] ||= nil
    end

    # Cache a value
    def cache(name, value)
        Puppet::Util::Storage.cache(self)[name] = value
        #@cache[name] = value
    end

#    def set(name, value)
#        send(name.to_s + "=", value)
#    end
#
#    def get(name)
#        send(name)
#    end

    # For now, leave the 'name' method functioning like it used to.  Once 'title'
    # works everywhere, I'll switch it.
    def name
        return self[:name]
    end

    # Look up our parent in the catalog, if we have one.
    def parent
        return nil unless catalog

        unless defined?(@parent)
            # This is kinda weird.
            if implicit?
                parents = catalog.relationship_graph.adjacent(self, :direction => :in)
            else
                parents = catalog.adjacent(self, :direction => :in)
            end
            if parents
                # We should never have more than one parent, so let's just ignore
                # it if we happen to.
                @parent = parents.shift
            else
                @parent = nil
            end
        end
        @parent
    end

    # Return the "type[name]" style reference.
    def ref
        "%s[%s]" % [self.class.name.to_s.capitalize, self.title]
    end
    
    def self_refresh?
        self.class.self_refresh
    end

    # Mark that we're purging.
    def purging
        @purging = true
    end

    # Is this resource being purged?  Used by transactions to forbid
    # deletion when there are dependencies.
    def purging?
        if defined? @purging
            @purging
        else
            false
        end
    end

    # Retrieve the title of an object.  If no title was set separately,
    # then use the object's name.
    def title
        unless defined? @title and @title
            namevar = self.class.namevar
            if self.class.validparameter?(namevar)
                @title = self[:name]
            elsif self.class.validproperty?(namevar)
                @title = self.should(namevar)
            else
                self.devfail "Could not find namevar %s for %s" %
                    [namevar, self.class.name]
            end
        end

        return @title
    end

    # convert to a string
    def to_s
        self.ref
    end

    # Convert to a transportable object
    def to_trans(ret = true)
        trans = TransObject.new(self.title, self.class.name)

        values = retrieve()
        values.each do |name, value|
            trans[name.name] = value
        end

        @parameters.each do |name, param|
            # Avoid adding each instance name as both the name and the namevar
            next if param.class.isnamevar? and param.value == self.title

            # We've already got property values
            next if param.is_a?(Puppet::Property)
            trans[name] = param.value
        end

        trans.tags = self.tags

        # FIXME I'm currently ignoring 'parent' and 'path'

        return trans
    end

end # Puppet::Type
end

require 'puppet/provider'

# Always load these types.
require 'puppet/type/component'
