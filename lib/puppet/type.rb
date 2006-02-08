require 'puppet'
require 'puppet/log'
require 'puppet/element'
require 'puppet/event'
require 'puppet/metric'
require 'puppet/type/state'
require 'puppet/parameter'
require 'puppet/util'
# see the bottom of the file for the rest of the inclusions

module Puppet
class Type < Puppet::Element
    # Types (which map to elements in the languages) are entirely composed of
    # attribute value pairs.  Generally, Puppet calls any of these things an
    # 'attribute', but these attributes always take one of three specific
    # forms:  parameters, metaparams, or states.

    # In naming methods, I have tried to consistently name the method so
    # that it is clear whether it operates on all attributes (thus has 'attr' in
    # the method name, or whether it operates on a specific type of attributes.
    attr_accessor :children, :parent
    attr_accessor :file, :line, :tags

    attr_writer :implicit
    def implicit?
        if defined? @implicit and @implicit
            return true
        else
            return false
        end
    end

    include Enumerable

    # this is currently unused, but I expect to use it for metrics eventually
    @@retrieved = Hash.new(0)

    # an array to contain all instances of Type
    # also currently unused
    @@allobjects = Array.new

    # a little fakery, since Puppet itself isn't a type
    # I don't think this is used any more, now that the language can't
    # call methods
    #@name = :puppet

    # set it to something to silence the tests, but otherwise not used
    #@namevar = :notused

    # again, silence the tests; the :notused has to be there because it's
    # the namevar
    
    # class methods dealing with Type management

    public

    # the Type class attribute accessors
    class << self
        attr_reader :name, :states

        include Enumerable

        def inspect
            Puppet.info "inspecting class with name %s" % self.name
            "Type(%s)" % self.name
        end

        # This class is aggregatable, meaning that instances are defined on
        # one system but instantiated on another
        def isaggregatable
            @aggregatable = true
        end

        # Is this one aggregatable?
        def aggregatable?
            if defined? @aggregatable
                return @aggregatable
            else
                return false
            end
        end
    end

    def inspect
        str = "Type(%s)" % self.name
        if defined? @states
            str += " States(" + @states.inspect + ")"
        end
        if defined? @parameters
            str += " Parameters(" + @parameters.inspect + ")"
        end
        if defined? @metaparams
            str += " Metaparams(" + @metaparams.inspect + ")"
        end
        str
    end

    # iterate across all of the subclasses of Type
    def self.eachtype
        @types.each do |name, type|
            # Only consider types that have names
            #if ! type.parameters.empty? or ! type.validstates.empty?
                yield type 
            #end
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

    # The work that gets done for every subclass of Type
    # this is an implicit method called by Ruby for us
    #def self.inherited(sub)
    #    sub.initvars

        #debug("subtype %s(%s) just created" % [sub,sub.superclass])
        # add it to the master list
        # unfortunately we can't yet call sub.name, because the #inherited
        # method gets called before any commands in the class definition
        # get executed, which, um, sucks
        #@@typeary.push(sub)
    #end

    # all of the variables that must be initialized for each subclass
    def self.initvars
        # all of the instances of this class
        @objects = Hash.new
        @aliases = Hash.new

        unless defined? @parameters
            @parameters = []
        end

        @validstates = {}

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

        unless defined? @states
            @states = []
        end

    end

    # Define a new type.
    def self.newtype(name, parent = nil, &block)
        parent ||= Puppet::Type
        Puppet::Util.symbolize(name)


        # Create the class, with the correct name.
        t = Class.new(parent) do
            @name = name
        end
        const_set(name.to_s.capitalize,t)

        # Initialize any necessary variables.
        t.initvars

        # Evaluate the passed block.  This should usually define all of the work.
        t.class_eval(&block)

        # If they've got all the necessary methods defined and they haven't
        # already added the state, then do so now.
        if t.ensurable? and ! t.validstate?(:ensure)
            t.ensurable
        end

        @types ||= {}

        # And add it to our bucket.
        @types[name] = t
    end

    # Create the 'ensure' class.  This is a separate method so other types
    # can easily call it and create their own 'ensure' values.
    def self.ensurable(&block)
        if block_given?
            self.newstate(:ensure, Puppet::State::Ensure, &block)
        else
            self.newstate(:ensure, Puppet::State::Ensure) do
                self.defaultvalues
            end
        end
    end

    # Return a Type instance by name.
    def self.type(name)
        @types ||= {}

        if name.is_a?(String)
            name = name.intern
        end

        @types[name]
    end

    # class methods dealing with type instance management

    public

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

    # retrieve a named instance of the current type
    def self.[](name)
        if @objects.has_key?(name)
            return @objects[name]
        elsif @aliases.has_key?(name)
            return @aliases[name]
        else
            return nil
        end
    end

    # add an instance by name to the class list of instances
    def self.[]=(name,object)
        newobj = nil
        if object.is_a?(Puppet::Type)
            newobj = object
        else
            raise Puppet::DevError, "must pass a Puppet::Type object"
        end

        if @objects.has_key?(name) and self.isomorphic?
            raise Puppet::Error.new(
                "Object '%s' of type '%s' already exists with id '%s' vs. '%s'" %
                [name, newobj.class.name,
                    @objects[name].object_id,newobj.object_id]
            )
        else
            #Puppet.info("adding %s of type %s to class list" %
            #    [name,object.class])
            @objects[name] = newobj
        end

        # and then add it to the master list
        Puppet::Type.push(object)
    end

    # remove all type instances; this is mostly only useful for testing
    def self.allclear
        @@allobjects.clear
        Puppet::Event::Subscription.clear
        @types.each { |name, type|
            type.clear
        }
        @finalized = false
    end

    # remove all of the instances of a single type
    def self.clear
        if defined? @objects
            @objects.clear
        end
        if defined? @aliases
            @aliases.clear
        end
    end

    # remove a specified object
    def self.delete(object)
        if @@allobjects.include?(object)
            @@allobjects.delete(object)
        end
        return unless defined? @objects
        if @objects.include?(object.name)
            @objects.delete(object.name)
        end
    end

    # iterate across each of the type's instances
    def self.each
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end

    # Perform any operations that need to be done between instance creation
    # and instance evaluation.
    def self.finalize
        finished = {}
        self.eachtype do |type|
            type.each do |object|
                unless finished.has_key?(object)
                    object.finish
                    finished[object] = true
                end
            end
        end
        self.mkdepends

        @finalized = true
    end

    # Has the finalize method been called yet?
    def self.finalized?
        if defined? @finalized
            return @finalized
        else
            return false
        end
    end

    # does the type have an object with the given name?
    def self.has_key?(name)
        return @objects.has_key?(name)
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

    # add an object to the master list of Type instances
    # I'm pretty sure this is currently basically unused
    def self.push(object)
        @@allobjects.push object
        #debug("adding %s of type %s to master list" %
        #    [object.name,object.class])
    end

    # class and instance methods dealing with parameters and states

    public

    # build a per-Type hash, mapping the states to their names
    def self.buildstatehash
        unless defined? @validstates
            @validstates = Hash.new(false)
        end
        return unless defined? @states
        @states.each { |stateklass|
            name = stateklass.name
            if @validstates.include?(name) 
                if @validstates[name] != stateklass
                    raise Puppet::Error.new("Redefining state %s(%s) in %s" %
                        [name,stateklass,self])
                else
                    # it's already there, so don't bother
                end
            else
                @validstates[name] = stateklass
            end
        }
    end

    # Find the namevar
    def self.namevar
        unless defined? @namevar
            return nil unless defined? @parameters and ! @parameters.empty?
            @namevar = @parameters.find { |name, param|
                param.isnamevar?
                unless param
                    raise Puppet::DevError, "huh? %s" % name
                end
            }[0].value
        end
        @namevar
    end

    # Copy an existing class parameter.  This allows other types to avoid
    # duplicating a parameter definition, and is mostly used by subclasses
    # of the File class.
    def self.copyparam(klass, name)
        param = klass.attrclass(name)

        unless param
            raise Puppet::DevError, "Class %s has no param %s" % [klass, name]
        end
        @parameters ||= []
        @parameters << param

        @paramhash ||= {}
        @parameters.each { |p| @paramhash[name] = p }

        if param.isnamevar?
            @namevar = param.name
        end
    end

    # Create a new metaparam.  Requires a block and a name, stores it in the
    # @parameters array, and does some basic checking on it.
    def self.newmetaparam(name, &block)
        Puppet::Util.symbolize(name)
        param = Class.new(Puppet::Parameter) do
            @name = name
        end
        param.ismetaparameter
        param.class_eval(&block)
        const_set("MetaParam" + name.to_s.capitalize,param)
        @@metaparams ||= []
        @@metaparams << param

        @@metaparamhash ||= {}
        @@metaparams.each { |p| @@metaparamhash[name] = p }
    end

    def self.eachmetaparam
        @@metaparams.each { |p| yield p.name }
    end

    # Create a new parameter.  Requires a block and a name, stores it in the
    # @parameters array, and does some basic checking on it.
    def self.newparam(name, &block)
        Puppet::Util.symbolize(name)
        param = Class.new(Puppet::Parameter) do
            @name = name
        end
        param.element = self
        param.class_eval(&block)
        const_set("Parameter" + name.to_s.capitalize,param)
        @parameters ||= []
        @parameters << param

        @paramhash ||= {}
        @parameters.each { |p| @paramhash[name] = p }

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
    end

    # Create a new state.
    def self.newstate(name, parent = nil, &block)
        parent ||= Puppet::State
        if @validstates.include?(name) 
            raise Puppet::DevError, "Class %s already has a state named %s" %
                [self.name, name]
        end
        s = Class.new(parent) do
            @name = name
        end
        const_set("State" + name.to_s.capitalize,s)
        s.class_eval(&block)
        @states ||= []

        # If it's the 'ensure' state, always put it first.
        if name == :ensure
            @states.unshift s
        else
            @states << s
        end
        @validstates[name] = s

#        define_method(name) do
#            @states[name].should
#        end
#
#        define_method(name.to_s + "=") do |value|
#            newstate(name, :should => value)
#        end

        return s
    end

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

    # Return the parameter names
    def self.parameters
        return [] unless defined? @parameters
        @parameters.collect { |klass| klass.name }
    end

    # Find the metaparameter class associated with a given metaparameter name.
    def self.metaparamclass(name)
        @@metaparamhash[name]
    end

    # Find the parameter class associated with a given parameter name.
    def self.paramclass(name)
        @paramhash[name]
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

    # does the name reflect a valid state?
    def self.validstate?(name)
        unless @validstates.length == @states.length
            self.buildstatehash
        end
        if @validstates.include?(name)
            return @validstates[name]
        else
            return false
        end
    end

    # Return the list of validstates
    def self.validstates
        return {} unless defined? @states
        unless @validstates.length == @states.length
            self.buildstatehash
        end

        return @validstates.keys
    end

    # Return the state class associated with a name
    def self.statebyname(name)
        unless @validstates.length == @states.length
            self.buildstatehash
        end
        @validstates[name]
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

    # What type of parameter are we dealing with? Cache the results, because
    # this method gets called so many times.
    def self.attrtype(name)
        @attrtypes ||= {}
        unless @attrtypes.include?(name)
            @attrtypes[name] = case
                when @validstates.include?(name): :state
                when @@metaparamhash.include?(name): :meta
                when @paramhash.include?(name): :param
                else
                    raise Puppet::DevError, "Invalid attribute '%s' for class '%s'" %
                        [name, self.name]
                end
        end

        @attrtypes[name]
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

    def self.validattr?(name)
        if name.is_a?(String)
            name = name.intern
        end
        if self.validstate?(name) or self.validparameter?(name) or self.metaparam?(name)
            return true
        else
            return false
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
            # if they've got a method to handle the parameter, then do it that way
            self.newparam(self.class.attrclass(name), value)
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

    # iterate across all children, and then iterate across states
    # we do children first so we're sure that all dependent objects
    # are checked first
    # we ignore parameters here, because they only modify how work gets
    # done, they don't ever actually result in work specifically
    def each
        # we want to return the states in the order that each type
        # specifies it, because it may (as in the case of File#create)
        # be important
        if self.class.depthfirst?
            @children.each { |child|
                yield child
            }
        end
        self.eachstate { |state|
            yield state
        }
        unless self.class.depthfirst?
            @children.each { |child|
                yield child
            }
        end
    end

    # iterate across the existing states
    def eachstate
        # states() is a private method
        states().each { |state|
            yield state
        }
    end

    def devfail(msg)
        self.fail(Puppet::DevError, msg)
    end

    # Throw an error, defaulting to a Puppet::Error
    def fail(*args)
        type = nil
        if args[0].is_a?(Class)
            type = args.shift
        else
            type = Puppet::Error
        end

        error = type.new(args.join(" "))

        if defined? @line and @line
            error.line = @line
        end

        if defined? @file and @file
            error.file = @file
        end

        raise error
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
    
    # create a log at specified level
    def log(msg)
        Puppet::Log.create(
            :level => @metaparams[:loglevel].value,
            :message => msg,
            :source => self
        )
    end

    # is the instance a managed instance?  A 'yes' here means that
    # the instance was created from the language, vs. being created
    # in order resolve other questions, such as finding a package
    # in a list
    def managed?
        if defined? @managed
            return @managed
        else
            @managed = false
            states.each { |state|
                if state.should and ! state.class.unmanaged
                    @managed = true
                end
            }
            return @managed
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
        if value
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

    def push(*childs)
        unless defined? @children
            @children = []
        end
        childs.each { |child|
            @children.push(child)
            child.parent = self
        }
    end

    # Remove an object.  The argument determines whether the object's
    # subscriptions get eliminated, too.
    def remove(rmdeps = true)
        @children.each { |child|
            child.remove(rmdeps)
        }

        if rmdeps
            Puppet::Event::Subscription.dependencies(self).each { |dep|
                begin
                    self.unsubscribe(dep)
                rescue
                    # ignore failed unsubscribes
                end
            }
        end
        self.class.delete(self)

        if defined? @parent and @parent
            @parent.delete(self)
        end
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


    # instance methods related to instance intrinsics
    # e.g., initialize() and name()

    public

    # Force users to call this, so that we can merge objects if
    # necessary.  FIXME This method should be responsible for most of the
    # error handling.
    def self.create(hash)
        # Handle this new object being implicit
        implicit = hash[:implicit] || false
        if hash.include?(:implicit)
            hash.delete(:implicit)
        end

        name = nil
        unless name =   hash["name"] || hash[:name] ||
                    hash[self.namevar] || hash[self.namevar.to_s]
            raise Puppet::Error, "You must specify a name for objects of type %s" %
                self.to_s
        end
        # if the object already exists
        if self.isomorphic? and retobj = self[name]
            # if only one of our objects is implicit, then it's easy to see
            # who wins -- the non-implicit one.
            if retobj.implicit? and ! implicit
                Puppet.notice "Removing implicit %s" % retobj.name
                # Remove all of the objects, but do not remove their subscriptions.
                retobj.remove(false)

                # now pass through and create the new object
            elsif implicit
                Puppet.notice "Ignoring implicit %s" % name

                return retobj
            else
                # We will probably want to support merging of some kind in
                # the future, but for now, just throw an error.
                raise Puppet::Error, "%s '%s' is already being managed" %
                    [self.name, name]
                #retobj.merge(hash)

                #return retobj
            end
        end

        # create it anew
        # if there's a failure, destroy the object if it got that far
        begin
            obj = new(hash)
        rescue => detail
            if Puppet[:debug]
                puts detail.backtrace
            end
            Puppet.err "Could not create %s: %s" % [name, detail.to_s]
            if obj
                obj.remove(true)
            elsif obj = self[name]
                obj.remove(true)
            end
            return nil
        end

        if implicit
            obj.implicit = true
        end

        return obj
    end

    def self.implicitcreate(hash)
        unless hash.include?(:implicit)
            hash[:implicit] = true
        end
        obj = self.create(hash)
        obj.implicit = true

        return obj
    end

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

    # and then make 'new' private
    class << self
        private :new
    end

    def initvars
        @children = []
        @evalcount = 0

        # callbacks are per object and event
        @callbacks = Hash.new { |chash, key|
            chash[key] = {}
        }

        # states and parameters are treated equivalently from the outside:
        # as name-value pairs (using [] and []=)
        # internally, however, parameters are merely a hash, while states
        # point to State objects
        # further, the lists of valid states and parameters are defined
        # at the class level
        unless defined? @states
            @states = Hash.new(false)
        end
        unless defined? @parameters
            @parameters = Hash.new(false)
        end
        unless defined? @metaparams
            @metaparams = Hash.new(false)
        end

        # set defalts
        @noop = false
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

        # If we got passed a transportable object, we just pull a bunch of info
        # directly from it.
        if hash.is_a?(Puppet::TransObject)
            #self[:name] = hash[:name]
            [:file, :line, :tags].each { |getter|
                if hash.respond_to?(getter)
                    setter = getter.to_s + "="
                    if val = hash.send(getter)
                        self.send(setter, val)
                    end
                end
            }
            hash = hash.to_hash
        end

        # Before anything else, set our parent if it was included
        if hash.include?(:parent)
            @parent = hash[:parent]
            hash.delete(:parent)
        end

        # Convert all args to symbols
        hash = self.argclean(hash)

        # Let's do the name first, because some things need to happen once
        # we have the name but before anything else

        attrs = self.class.allattrs
        namevar = self.class.namevar

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

        # The information to cache to disk.  We have to do this after
        # the name is set because it uses the name and/or path, but before
        # everything else is set because the states need to be able to
        # retrieve their stored info.
        #@cache = Puppet::Storage.cache(self)

        # This is all of our attributes except the namevar.
        attrs.each { |name|
            if hash.include?(name)
                begin
                    self[name] = hash[name]
                rescue => detail
                    self.devfail(
                        "Could not set %s on %s: %s" %
                            [name, self.class.name, detail]
                    )
                end
                hash.delete name
            end
        }

        # While this could theoretically be set after all of the objects are
        # created, it seems to make more sense to set them immediately.
        self.setdefaults

        if hash.length > 0
            self.debug hash.inspect
            self.fail("Class %s does not accept argument(s) %s" %
                [self.class.name, hash.keys.join(" ")])
        end

        # add this object to the specific class's list of objects
        #puts caller
        self.class[self.name] = self

        if self.respond_to?(:validate)
            self.validate
        end
    end

    # Figure out of there are any objects we can automatically add as
    # dependencies.
    def autorequire
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
                # Skip autorequires that we aren't managing
                next unless obj = typeobj[dep]

                # Skip autorequires that we already require
                next if self.requires?(obj)
                self.info "Auto-requiring %s" % obj.name

                self[:require] = [type, dep]
            }

            #self.info reqs.inspect
            #self[:require] = reqs
        }
    end

    # Set up all of our autorequires.
    def finish
        self.autorequire

        # Scheduling has to be done when the whole config is instantiated, so
        # that file order doesn't matter in finding them.
        self.schedule
    end

    # Return a cached value
    def cached(name)
        Puppet::Storage.cache(self)[name]
        #@cache[name] ||= nil
    end

    # Cache a value
    def cache(name, value)
        Puppet::Storage.cache(self)[name] = value
        #@cache[name] = value
    end

    # Look up the schedule and set it appropriately.  This is done after
    # the instantiation phase, so that the schedule can be anywhere in the
    # file.
    def schedule

        # If we've already set the schedule, then just move on
        return if self[:schedule].is_a?(Puppet.type(:schedule))

        return unless self[:schedule]

        # Schedules don't need to be scheduled
        #return if self.is_a?(Puppet.type(:schedule))

        # Nor do components
        #return if self.is_a?(Puppet.type(:component))

        if sched = Puppet.type(:schedule)[self[:schedule]]
            self[:schedule] = sched
        else
            self.fail "Could not find schedule %s" % self[:schedule]
        end
#        if self[:schedule]
#        elsif Puppet[:schedule] and ! Puppet[:ignoreschedules]
#            # We handle schedule defaults here mostly because otherwise things
#            # will behave very very erratically during testing.
#            if sched = Puppet.type(:schedule)[Puppet[:schedule]]
#                self[:schedule] = sched
#            else
#                self.fail "Could not find default schedule %s" % Puppet[:schedule]
#            end
#        else
#            # While it's unlikely we won't have any schedule (since there's a
#            # default), it's at least possible during testing
#            return true
#        end
    end

    # Check whether we are scheduled to run right now or not.
    def scheduled?
        return true if Puppet[:ignoreschedules]
        return true unless schedule = self[:schedule]

        # We use 'checked' here instead of 'synced' because otherwise we'll
        # end up checking most elements most times, because they will generally
        # have been synced a long time ago (e.g., a file only gets updated
        # once a month on the server and its schedule is daily; the last sync time
        # will have been a month ago, so we'd end up checking every run).
        return schedule.match?(self.cached(:checked).to_i)
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
            #self.debug "defaulting %s to %s" % [obj.name, obj.default]
            obj.value = obj.default
        }

    end

    # Merge new information with an existing object, checking for conflicts
    # and such.  This allows for two specifications of the same object and
    # the same values, but it's pretty limited right now.  The result of merging
    # states is very different from the result of merging parameters or metaparams.
    # This is currently unused.
    def merge(hash)
        hash.each { |param, value|
            if param.is_a?(String)
                param = param.intern
            end
            
            # Of course names are the same, duh.
            next if param == :name or param == self.class.namevar

            unless value.is_a?(Array)
                value = [value]
            end

            if oldvals = @states[param].shouldorig
                unless oldvals.is_a?(Array)
                    oldvals = [oldvals]
                end
                # If the values are exactly the same, order and everything,
                # then it's okay.
                if oldvals == value
                    return true
                end
                # take the intersection
                newvals = oldvals & value
                if newvals.empty?
                    self.fail "No common values for %s on %s(%s)" %
                        [param, self.class.name, self.name]
                elsif newvals.length > 1
                    self.fail "Too many values for %s on %s(%s)" %
                        [param, self.class.name, self.name]
                else
                    self.debug "Reduced old values %s and new values %s to %s" %
                        [oldvals.inspect, value.inspect, newvals.inspect]
                    @states[param].should = newvals
                    #self.should = newvals
                    return true
                end
            else
                self[param] = value
            end
        }
    end

    # derive the instance name based on class.namevar
    def name
        unless defined? @name and @name
            namevar = self.class.namevar
            if self.class.validparameter?(namevar)
                @name = self[:name]
            elsif self.class.validstate?(namevar)
                @name = self.should(namevar)
            else
                self.devfail "Could not find namevar %s for %s" %
                    [namevar, self.class.name]
            end
        end

        unless @name
            self.devfail "Could not find namevar '%s' for %s" %
                [self.class.namevar, self.class.name]
        end

        return @name
    end

    # fix any namevar => param translations
    def argclean(hash)
        # We have to set the name of our object before anything else,
        # because it might be used in creating the other states.  We dup and
        # then convert to a hash here because TransObjects behave strangely
        # here.
        hash = hash.dup.to_hash

        if hash.include?(:parent)
            hash.delete(:parent)
        end
        namevar = self.class.namevar

        hash.each { |var,value|
            unless var.is_a? Symbol
                hash[var.intern] = value
                hash.delete(var)
            end
        }

        # if they're not using :name for the namevar but we got :name (probably
        # from the parser)
        if namevar != :name and hash.include?(:name) and ! hash[:name].nil?
            #self[namevar] = hash[:name]
            hash[namevar] = hash[:name]
            hash.delete(:name)
        # else if we got the namevar
        elsif hash.has_key?(namevar) and ! hash[namevar].nil?
            #self[namevar] = hash[namevar]
            #hash.delete(namevar)
        # else something's screwy
        else
            # they didn't specify anything related to names
        end

        return hash
    end

    # retrieve the current value of all contained states
    def retrieve
        # it's important to use the method here, as it follows the order
        # in which they're defined in the object
        states().each { |state|
            state.retrieve
        }
    end

    # convert to a string
    def to_s
        self.name
    end

    # instance methods dealing with actually doing work

    public

    # this is a retarded hack method to get around the difference between
    # component children and file children
    def self.depthfirst?
        if defined? @depthfirst
            return @depthfirst
        else
            return false
        end
    end

    # Retrieve the changes associated with all of the states.
    def statechanges
        # If we are changing the existence of the object, then none of
        # the other states matter.
        if @states.include?(:ensure) and ! @states[:ensure].insync?
            #self.info "ensuring %s from %s" %
            #    [@states[:ensure].should, @states[:ensure].is]
            return [Puppet::StateChange.new(@states[:ensure])]
        # Else, if the 'ensure' state is correctly absent, then do
        # nothing
        elsif @states.include?(:ensure) and @states[:ensure].is == :absent
            #self.info "Object is correctly absent"
            return []
        else
            #if @states.include?(:ensure)
            #    self.info "ensure: Is: %s, Should: %s" %
            #        [@states[:ensure].is, @states[:ensure].should]
            #else
            #    self.info "no ensure state"
            #end
            return states().find_all { |state|
                ! state.insync?
            }.collect { |state|
                Puppet::StateChange.new(state)
            }
        end
    end

    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
        now = Time.now

        #Puppet.err "Evaluating %s" % self.path.join(":")
        unless defined? @evalcount
            self.err "No evalcount defined on '%s' of type '%s'" %
                [self.name,self.class]
            @evalcount = 0
        end
        @@retrieved[self] += 1
        # if we're a metaclass and we've already evaluated once...
        #if self.metaclass and @evalcount > 0
        #    return
        #end
        @evalcount += 1

        #changes = @children.collect { |child|
        #    child.evaluate
        #}

        changes = []
        # collect all of the changes from children and states
        #if self.class.depthfirst?
        #    changes << self.collect { |child|
        #        child.evaluate
        #    }
        #end

        # this only operates on states, not states + children
        # it's important that we call retrieve() on the type instance,
        # not directly on the state, because it allows the type to override
        # the method, like pfile does
        self.retrieve

        # states() is a private method, returning an ordered list
        unless self.class.depthfirst?
            changes += statechanges()
        end

        if changes.length > 0
            # add one to the number of out-of-sync instances
            Puppet::Metric.add(self.class,self,:outofsync,1)
        end
        #end

        changes << @children.collect { |child|
            ch = child.evaluate
            child.cache(:checked, now)
            ch
        }
        #unless self.class.depthfirst?
        #    changes << self.collect { |child|
        #        child.evaluate
        #    }
        #end
        # collect changes and return them
        # these changes could be from child objects or from contained states
        #self.collect { |child|
        #    child.evaluate
        #}

        if self.class.depthfirst?
            changes += statechanges()
        end

        changes.flatten!

        # now record how many changes we've resulted in
        Puppet::Metric.add(self.class,self,:changes,changes.length)
        if changes.length > 0
            self.info "%s change(s)" %
                [changes.length]
            #changes.each { |change|
            #    self.debug "change: %s" % change.state.name
            #}
        end
        self.cache(:checked, now)
        return changes.flatten
    end

    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more,
    # it's really only used for testing
    def insync?
        insync = true

        if state = @states[:ensure]
            if state.insync? and state.should == :absent
                return true
            end
        end

        states.each { |state|
            unless state.insync?
                self.debug("%s is not in sync: %s vs %s" %
                    [state, state.is.inspect, state.should.inspect])
                insync = false
            end
        }

        #self.debug("%s sync status is %s" % [self,insync])
        return insync
    end

    # Meta-parameter methods:  These methods deal with the results
    # of specifying metaparameters

    def self.metaparams
        @@metaparams.collect { |param| param.name }
    end

    # Is the parameter in question a meta-parameter?
    def self.metaparam?(param)
        @@metaparamhash.include?(param)
    end

    # Subscription and relationship methods

    #def addcallback(object, event, method)
    #    @callbacks[object][event] = method
    #end

    # Build all of the dependencies for all of the different types.  This is called
    # after all of the objects are instantiated, so that we don't depend on
    # file order.  If we didn't use this (and instead just checked dependencies
    # as we came across them), any required object would have to come before the
    # requiring object in the file(s).
    def self.mkdepends
        @types.each { |name, type|
            type.each { |obj|
                obj.builddepends
            }
        }
    end

    # The per-type version of dependency building.  This actually goes through
    # all of the objects themselves and builds deps.
    def self.builddepends
        return unless defined? @objects
        @objects.each { |name, obj|
            obj.builddepends
        }
    end

    # Build the dependencies associated with an individual object.
    def builddepends
        # Handle the requires
        if self[:require]
            self.handledepends(self[:require], :NONE, nil)
        end

        # And the subscriptions
        if self[:subscribe]
            self.handledepends(self[:subscribe], :ALL_EVENTS, :refresh)
        end
    end

    # return all objects that we depend on
    def eachdependency
        Puppet::Event::Subscription.dependencies(self).each { |dep|
            yield dep.source
        }
    end

    # return all objects subscribed to the current object
    #def eachsubscriber
    #    Puppet::Event::Subscriptions.subscribers?(self).each { |sub|
    #        yield sub.targetobject
    #    }
    #end

    def handledepends(requires, event, method)
        # Requires are specified in the form of [type, name], so they're always
        # an array.  But we want them to be an array of arrays.
        unless requires[0].is_a?(Array)
            requires = [requires]
        end
        requires.each { |rname|
            # we just have a name and a type, and we need to convert it
            # to an object...
            type = nil
            object = nil
            tname = rname[0]
            unless type = Puppet::Type.type(tname)
                self.fail "Could not find type %s" % tname.inspect
            end
            name = rname[1]
            unless object = type[name]
                self.fail "Could not retrieve object '%s' of type '%s'" %
                    [name,type]
            end
            self.debug("subscribes to %s" % [object])

            #unless @dependencies.include?(object)
            #    @dependencies << object
            #end

            # pure requires don't call methods
            #next if method.nil?

            # ok, both sides of the connection store some information
            # we store the method to call when a given subscription is 
            # triggered, but the source object decides whether 
            subargs = {
                :event => event,
                :source => object,
                :target => self
            }
            if method and self.respond_to?(method)
                subargs[:callback] = method
            end
            Puppet::Event::Subscription.new(subargs)
        }
    end

    # Trigger any associated subscriptions, and then pass the event up to our
    # parent.
    def propagate(event, transaction)
        Puppet::Event::Subscription.trigger(self, event, transaction)

        if defined? @parent
            @parent.propagate(event, transaction)
        end
    end

    def requires?(object)
        req = false
        self.eachdependency { |dep|
            if dep == object
                req = true
                break
            end
        }

        return req
    end

    def subscribe(hash)
        hash[:source] = self
        Puppet::Event::Subscription.new(hash)

        # add to the correct area
        #@subscriptions.push sub
    end

    # Unsubscribe from a given object, possibly with a specific event.
    def unsubscribe(object, event = nil)
        Puppet::Event::Subscription.dependencies(self).find_all { |sub|
            if event
                sub.match?(event)
            else
                sub.source == object
            end
        }.each { |sub|
            Puppet::Event::Subscription.delete(sub)
        }
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

    # Documentation methods
    def self.paramdoc(param)
        @paramhash[param].doc
    end
    def self.metaparamdoc(metaparam)
        @@metaparamhash[metaparam].doc
    end

    # Add all of the meta parameters.
    #newmetaparam(:onerror) do
    #    desc "How to handle errors -- roll back innermost
    #        transaction, roll back entire transaction, ignore, etc.  Currently
    #        non-functional."
    #end

    newmetaparam(:noop) do
        desc "Boolean flag indicating whether work should actually
            be done.  *true*/**false**"
        munge do |noop|
            if noop == "true" or noop == true
                return true
            elsif noop == "false" or noop == false
                return false
            else
                self.fail("Invalid noop value '%s'" % noop)
            end
        end
    end

    newmetaparam(:schedule) do
        desc "On what schedule the object should be managed.  You must create a
            schedule_ object, and then reference the name of that object to use
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

        munge do |name|
            if schedule = Puppet.type(:schedule)[name]
                return schedule
            else
                return name
            end
        end
    end

    newmetaparam(:check) do
        desc "States which should have their values retrieved
            but which should not actually be modified.  This is currently used
            internally, but will eventually be used for querying, so that you
            could specify that you wanted to check the install state of all
            packages, and then query the Puppet client daemon to get reports
            on all packages."

        munge do |args|
            unless args.is_a?(Array)
                args = [args]
            end

            unless defined? @parent
                self.devfail "No parent for %s, %s?" %
                    [self.class, self.name]
            end

            args.each { |state|
                unless state.is_a?(Symbol)
                    state = state.intern
                end
                next if @parent.statedefined?(state)

                @parent.newstate(state)
            }
        end
    end
    # For each object we require, subscribe to all events that it generates. We
    # might reduce the level of subscription eventually, but for now...
    newmetaparam(:require) do
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
                    require => file[\"/usr/local/scripts\"]
                }

            Note that Puppet will autorequire everything that it can, and
            there are hooks in place so that it's easy for elements to add new
            ways to autorequire objects, so if you think Puppet could be
            smarter here, let us know.

            In fact, the above code was redundant -- Puppet will autorequire
            any parent directories that are being managed; it will
            automatically realize that the parent directory should be created
            before the script is pulled down.
            
            Currently, exec_ elements will autorequire their CWD (if it is
            specified) plus any fully qualified paths that appear in the
            command.   For instance, if you had an ``exec`` command that ran
            the ``myscript`` mentioned above, the above code that pulls the
            file down would be automatically listed as a requirement to the
            ``exec`` code, so that you would always be running againts the
            most recent version.
            "

        # Take whatever dependencies currently exist and add these.
        # Note that this probably doesn't behave correctly with unsubscribe.
        munge do |requires|
            # We need to be two arrays deep...
            unless requires.is_a?(Array)
                requires = [requires]
            end
            unless requires[0].is_a?(Array)
                requires = [requires]
            end
            if values = @parent[:require]
                requires = values + requires
            end
            requires
            #p @parent[:require]
            #@parent.handledepends(requires, :NONE, nil)
        end
    end

    # For each object we require, subscribe to all events that it generates.
    # We might reduce the level of subscription eventually, but for now...
    newmetaparam(:subscribe) do
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
                        require => file[nagconf]
                    }
                }
            "

        munge do |requires|
            if values = @parent[:subscribe]
                requires = values + requires
            end
            requires
        #    @parent.handledepends(requires, :ALL_EVENTS, :refresh)
        end
    end

    newmetaparam(:loglevel) do
        desc "Sets the level that information will be logged:
             debug, info, verbose, notice, warning, err, alert, emerg or crit.
             The log levels have the biggest impact when logs are sent to
             syslog (which is currently the default)."
        defaultto :notice

        validate do |loglevel|
            if loglevel.is_a?(String)
                loglevel = loglevel.intern
            end
            unless Puppet::Log.validlevel?(loglevel)
                self.fail "Invalid log level %s" % loglevel
            end
        end

        munge do |loglevel|
            if loglevel.is_a?(String)
                loglevel = loglevel.intern
            end
            if loglevel == :verbose
                loglevel = :info 
            end        
            loglevel
        end
    end

    newmetaparam(:alias) do
        desc "Creates an alias for the object.  This simplifies lookup of the
            object so is useful in the language.  It is especially useful when
            you are creating long commands using exec or when many different
            systems call a given package_ different names::

            
                file { \"/usr/local/scripts/myscript\":
                    source => \"puppet://server/module/myscript\",
                    mode => 755,
                    alias => myscript
                }

                exec { \"/usr/local/scripts/myscript\":
                    require => file[myscript]
                }
            
            Again, this is somewhat redundant, since any sane person would
            just use a variable (unless the two statements were in different
            scopes), and Puppet will autorequire the script anyway, but it
            gets the point across."

        munge do |aliases|
            unless aliases.is_a?(Array)
                aliases = [aliases]
            end
            @parent.info "Adding aliases %s" % aliases.join(", ")
            aliases.each do |other|
                if obj = @parent.class[other]
                    unless obj == @parent
                        self.fail(
                            "%s an not create alias %s: object already exists" %
                            [@parent.name, other]
                        )
                    end
                    next
                end
                @parent.class.alias(other, @parent)
            end
        end
    end
end # Puppet::Type
end

require 'puppet/statechange'
require 'puppet/type/component'
require 'puppet/type/cron'
require 'puppet/type/exec'
require 'puppet/type/group'
require 'puppet/type/package'
require 'puppet/type/pfile'
require 'puppet/type/pfilebucket'
require 'puppet/type/schedule'
require 'puppet/type/service'
require 'puppet/type/symlink'
require 'puppet/type/user'
require 'puppet/type/tidy'
require 'puppet/type/parsedtype'

# $Id$
