require 'puppet'
require 'puppet/log'
require 'puppet/element'
require 'puppet/event'
require 'puppet/metric'
require 'puppet/type/state'
require 'puppet/parameter'
require 'puppet/util'
# see the bottom of the file for the rest of the inclusions

module Puppet # :nodoc:
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
    @name = :puppet

    # set it to something to silence the tests, but otherwise not used
    @namevar = :notused

    # again, silence the tests; the :notused has to be there because it's
    # the namevar
    @states = []
    @parameters = [:notused]
    
    # @paramdoc = Hash.new
    
    @@metaparamdoc = Hash.new { |hash,key|
        if key.is_a?(String)
            key = key.intern
        end
        if hash.include?(key)
            hash[key]
        else
            "Metaparam Documentation for %s not found" % key
        end
    }

    # class methods dealing with Type management

    public

    # these objects are used for mapping type names (e.g., 'file')
    # to actual object classes; because Type.inherited is
    # called before the <subclass>.name method is defined, we need
    # to store each class in an array, and then later actually iterate
    # across that array and make a map
    @@typeary = [self] # so that the allowedmethods stuff works
    @@typehash = Hash.new { |hash,key|
        if key.is_a?(String)
            key = key.intern
        end
        if hash.include?(key)
            hash[key]
        else
            raise TypeError.new("Object type %s not found" % key)
        end
    }

    # the Type class attribute accessors
    class << self
        attr_reader :name, :states, :parameters

        def inspect
            "Type(%s)" % self.name
        end

        def to_s
            self.inspect
        end
    end

    # Create @@typehash from @@typeary.  This is meant to be run
    # multiple times -- whenever it is discovered that the two
    # objects have differents lengths.
    def self.buildtypehash
        @@typeary.each { |otype|
            if @@typehash.include?(otype.name)
                if @@typehash[otype.name] != otype
                    Puppet.warning("Object type %s is already defined (%s vs %s)" %
                        [otype.name,@@typehash[otype.name],otype])
                end
            else
                @@typehash[otype.name] = otype
            end
        }
    end

    # iterate across all of the subclasses of Type
    def self.eachtype
        @@typeary.each do |type|
            # Only consider types that have names
            if type.name
                yield type 
            end
        end
    end

    # The work that gets done for every subclass of Type
    # this is an implicit method called by Ruby for us
    def self.inherited(sub)
        sub.initvars

        #debug("subtype %s(%s) just created" % [sub,sub.superclass])
        # add it to the master list
        # unfortunately we can't yet call sub.name, because the #inherited
        # method gets called before any commands in the class definition
        # get executed, which, um, sucks
        @@typeary.push(sub)
    end

    # all of the variables that must be initialized for each subclass
    def self.initvars
        # all of the instances of this class
        @objects = Hash.new

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

    # return a Type instance by name
    def self.type(type)
        unless @@typeary.length == @@typehash.length
            # call bulidtypehash if types have been added since it
            # was last called
            Type.buildtypehash
        end
        @@typehash[type]
    end

    # class methods dealing with type instance management

    public

    # retrieve a named instance of the current type
    def self.[](name)
        if @objects.has_key?(name)
            return @objects[name]
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

        if @objects.has_key?(newobj.name) and self.isomorphic?
            raise Puppet::Error.new(
                "Object '%s' of type '%s' already exists with id '%s' vs. '%s'" %
                [newobj.name,newobj.class.name,
                    @objects[newobj.name].object_id,newobj.object_id]
            )
        else
            #debug("adding %s of type %s to class list" %
            #    [object.name,object.class])
            @objects[newobj.name] = newobj
        end

        # and then add it to the master list
        Puppet::Type.push(object)
    end

    # remove all type instances; this is mostly only useful for testing
    def self.allclear
        @@allobjects.clear
        Puppet::Event::Subscription.clear
        @@typeary.each { |subtype|
            subtype.clear
        }
    end

    # remove all of the instances of a single type
    def self.clear
        if defined? @objects
            @objects.clear
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
            @namevar = @parameters.find { |name, param|
                param.isnamevar?
                unless param
                    raise Puppet::DevError, "huh? %s" % name
                end
            }[0]
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
        @@metaparams ||= []
        @@metaparams << param

        @@metaparamhash ||= {}
        @@metaparams.each { |p| @@metaparamhash[name] = p }
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
        @parameters ||= []
        @parameters << param

        @paramhash ||= {}
        @parameters.each { |p| @paramhash[name] = p }

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
        s.class_eval(&block)
        @states ||= []
        @states << s
        @validstates[name] = s

        return s
    end

    # Return the parameter names
    def self.parameters
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
        case self.attrtype(name)
        when :param: @paramhash[name]
        when :meta: @@metaparamhash[name]
        when :state: @validstates[name]
        end
    end

    def self.to_s
        "Puppet::Type::" + @name.to_s.capitalize
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

    # What type of parameter are we dealing with?
    def self.attrtype(name)
        case
        when @paramhash.include?(name): return :param
        when @@metaparamhash.include?(name): return :meta
        when @validstates.include?(name): return :state
        else
            raise Puppet::DevError, "Invalid parameter %s" % [name]
        end
    end

    # All parameters, in the appropriate order.  The namevar comes first,
    # then the states, then the params and metaparams in the order they
    # were specified in the files.
    def self.allattrs
        # now get all of the arguments, in a specific order
        order = [self.namevar]
        order << [self.states.collect { |state| state.name },
            self.parameters,
            self.metaparams].flatten.reject { |param|
                # we don't want our namevar in there multiple times
                param == self.namevar
        }

        order.flatten!

        return order
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
        if self.class.validstate?(name)
            if @states.include?(name)
                return @states[name].is
            else
                return nil
            end
        elsif Puppet::Type.metaparam?(name)
            if @metaparams.include?(name)
                return @metaparams[name].value
            else
                if default = self.class.metaattrclass(name).default
                    return default
                else
                    return nil
                end
            end
        elsif self.class.validparameter?(name)
            if @parameters.include?(name)
                return @parameters[name].value
            else
                if default = self.class.attrclass(name).default
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

        if Puppet::Type.metaparam?(name)
            self.newmetaparam(self.class.metaparamclass(name), value)
        elsif stateklass = self.class.validstate?(name) 
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
        elsif self.class.validparameter?(name)
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
            else
                raise Puppet::DevError.new("Undefined state '#{attr}' in #{self}")
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
            raise Puppet::DevError, "Invalid param type %s" % type
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
                raise Puppet::Error, "Invalid state %s" % name
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
        return @parameters[name]
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
    def remove(rmdeps)
        @children.each { |child|
            child.remove
        }
        self.class.delete(self)

        if rmdeps
            Puppet::Event::Subscription.dependencies(self).each { |dep|
                self.unsubscribe(dep)
            }
        end

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
            raise Puppet::DevError,
                "Something went very wrong with tmpstates creation"
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
                raise Puppet::Error, "%s %s is already being managed" %
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
                if detail.respond_to?(:stack)
                    puts detail.stack
                end
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
        # this isn't really sufficient either, because it adds lots of special cases
        # such as failed changes
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

        # Before anything else, set our parent if it was included
        if hash.include?(:parent)
            @parent = hash[:parent]
            hash.delete(:parent)
        end

        hash = self.argclean(hash)

        self.class.allattrs.each { |name|
            if hash.include?(name)
                begin
                    self[name] = hash[name]
                rescue => detail
                    raise Puppet::DevError.new( 
                        "Could not set %s on %s: %s" % [name, self.class.name, detail]
                    )
                end
                hash.delete name
            end
        }

        self.setdefaults

        if hash.length > 0
            self.debug hash.inspect
            raise Puppet::Error.new("Class %s does not accept argument(s) %s" %
                [self.class.name, hash.keys.join(" ")])
        end

        # add this object to the specific class's list of objects
        #puts caller
        self.class[self.name] = self

        if self.respond_to?(:validate)
            self.validate
        end
    end

    # Is the specified parameter set?
    def attrset?(type, attr)
        case type
        when :state: return @states.include?(attr)
        when :param: return @parameters.include?(attr)
        when :meta: return @metaparams.include?(attr)
        else
            raise Puppet::DevError, "Invalid set type %s" % [type]
        end
    end

    # For any parameters or states that have defaults and have not yet been
    # set, set them now.
    def setdefaults(*ary)
        if ary.empty?
            ary = self.class.allattrs
        end
        ary.each { |attr|
            type = self.class.attrtype(attr)
            next if self.attrset?(type, attr)

            klass = self.class.attrclass(attr)
            unless klass
                raise Puppet::DevError, "Could not retrieve class for %s" % attr
            end
            if klass.default
                obj = self.newattr(type, klass)
                obj.value = obj.default
            end
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
                    raise Puppet::Error, "No common values for %s on %s(%s)" %
                        [param, self.class.name, self.name]
                elsif newvals.length > 1
                    raise Puppet::Error, "Too many values for %s on %s(%s)" %
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
                raise Puppet::DevError, "Could not find namevar %s for %s" %
                    [namevar, self.class.name]
            end
        end

        unless @name
            raise Puppet::DevError, "Could not find namevar '%s' for %s" %
                [namevar, self.class.name]
        end

        return @name
    end

    # fix any namevar => param translations
    def argclean(hash)
        # we have to set the name of our object before anything else,
        # because it might be used in creating the other states
        hash = hash.dup

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
        states.each { |state|
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

    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
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
            changes << states().find_all { |state|
                ! state.insync?
            }.collect { |state|
                Puppet::StateChange.new(state)
            }
        end

        if changes.length > 0
            # add one to the number of out-of-sync instances
            Puppet::Metric.add(self.class,self,:outofsync,1)
        end
        #end

        changes << @children.collect { |child|
            child.evaluate
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
            changes << states().find_all { |state|
                ! state.insync?
            }.collect { |state|
                Puppet::StateChange.new(state)
            }
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
        return changes.flatten
    end

    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more,
    # it's really only used for testing
    def insync?
        insync = true

        states.each { |state|
            unless state.insync?
                self.debug("%s is not in sync: %s vs %s" %
                    [state, state.is, state.should])
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
                raise Puppet::Error, "Could not find type %s" % tname
            end
            name = rname[1]
            unless object = type[name]
                raise Puppet::Error, "Could not retrieve object '%s' of type '%s'" %
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
        #Puppet.notice "Checking reqs for %s" % object.name
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
        @paramdoc[param]
    end
    def self.metaparamdoc(metaparam)
        @@metaparamdoc[metaparam]
    end

    # Add all of the meta parameters.
    newmetaparam(:onerror) do
        desc "How to handle errors -- roll back innermost
            transaction, roll back entire transaction, ignore, etc.  Currently
            non-functional."
    end

    newmetaparam(:noop) do
        desc "Boolean flag indicating whether work should actually
            be done."
        munge do |noop|
            if noop == "true" or noop == true
                return true
            elsif noop == "false" or noop == false
                return false
            else
                raise Puppet::Error.new("Invalid noop value '%s'" % noop)
            end
        end
    end

    newmetaparam(:schedule) do
        desc "On what schedule the object should be managed.
            Currently non-functional."
    end

    newmetaparam(:check) do
        desc "States which should have their values retrieved
            but which should not actually be modified.  This is currently used
            internally, but will eventually be used for querying."

        munge do |args|
            unless args.is_a?(Array)
                args = [args]
            end

            unless defined? @parent
                raise Puppet::DevError, "No parent for %s, %s?" %
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
            happen before the dependent object."

        munge do |requires|
            @parent.handledepends(requires, :NONE, nil)
        end
    end

    # For each object we require, subscribe to all events that it generates.
    # We might reduce the level of subscription eventually, but for now...
    newmetaparam(:subscribe) do
        desc "One or more objects that this object depends on.
            Changes in the subscribed to objects result in the dependent objects being
            refreshed (e.g., a service will get restarted)."

        munge do |requires|
            @parent.handledepends(requires, :ALL_EVENTS, :refresh)
        end
    end

    newmetaparam(:loglevel) do
        desc "Sets the level that information will be logged:
             debug, info, verbose, notice, warning, err, alert, emerg or crit"
        defaultto :notice

        validate do |loglevel|
            if loglevel.is_a?(String)
                loglevel = loglevel.intern
            end
            unless Puppet::Log.validlevel?(loglevel)
                raise Puppet::Error, "Invalid log level %s" % loglevel
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
require 'puppet/type/service'
require 'puppet/type/symlink'
require 'puppet/type/user'
require 'puppet/type/tidy'
#require 'puppet/type/typegen'
#require 'puppet/type/typegen/filetype'
#require 'puppet/type/typegen/filerecord'

# $Id$
