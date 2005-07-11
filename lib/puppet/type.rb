#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'puppet'
require 'puppet/element'
require 'puppet/event'
require 'puppet/metric'
require 'puppet/type/state'


# XXX see the bottom of the file for the rest of the inclusions

#---------------------------------------------------------------
# This class is the abstract base class for the mechanism for organizing
# work.  No work is actually done by this class or its subclasses; rather,
# the subclasses include states which do the actual work.
#   See state.rb for how work is actually done.

# our duck type interface -- if your object doesn't match this interface,
# it won't work

# all of our first-class objects (objects, states, and components) will
# respond to these methods
# although states don't inherit from Puppet::Type
#   although maybe Puppet::State should...

# the default behaviour that this class provides is to just call a given
# method on each contained object, e.g., in calling 'sync', we just run:
# object.each { |subobj| subobj.sync() }

# to use this interface, just define an 'each' method and 'include Puppet::Type'

module Puppet
class Type < Puppet::Element
    attr_accessor :children, :parameters, :parent
    include Enumerable

    @@allobjects = Array.new # an array for all objects
    @abstract = true

    @name = :puppet # a little fakery, since Puppet itself isn't a type
    @namevar = :notused

    @states = []
    @parameters = [:notused]

    @allowedmethods = [:noop,:debug,:statefile]

    @@metaparams = [
        :onerror,
        :schedule,
        :check,
        :require
    ]

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # class methods dealing with Type management
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
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
            raise "Object type %s not found" % key
        end
    }

    #---------------------------------------------------------------
    # a test for whether this type is allowed to have instances
    # on clients
    # subclasses can just set '@abstract = true' to mark themselves
    # as abstract
    def Type.abstract
        if defined? @abstract
            return @abstract
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.allowedmethod(method)
        if defined? @allowedmethods and @allowedmethods.include?(method)
            return true
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.statefile(file)
        Puppet[:statefile] = file
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # ill thought-out
    # this needs to return @noop
    #def noop(ary)
    #    Puppet[:noop] = ary.shift
    #end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def debug(ary)
        value = ary.shift
        if value == "true" or value == true
            value = true
        else
            value = value
        end
        Puppet[:debug] = value
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this is meant to be run multiple times, e.g., when a new
    # type is defined at run-time
    def Type.buildtypehash
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.eachtype
        @@typeary.each { |type| yield type }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this should make it so our subclasses don't have to worry about
    # defining these class instance variables
    def Type.inherited(sub)
        sub.initvars

        #Puppet.debug("subtype %s(%s) just created" % [sub,sub.superclass])
        # add it to the master list
        # unfortunately we can't yet call sub.name, because the #inherited
        # method gets called before any commands in the class definition
        # get executed, which, um, sucks
        @@typeary.push(sub)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this is so we don't have to eval this code
    # init all of our class instance variables
    def Type.initvars
        @objects = Hash.new
        @actions = Hash.new
        #Puppet.debug "initing validstates for %s" % self
        @validstates = {}
        @validparameters = {}

        unless defined? @states
            @states = {}
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.metaclass
        if defined? @metaclass
            return @metaclass
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this is used for mapping object types (e.g., Puppet::Type::File)
    # to names (e.g., "file")
    def Type.name
        return @name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.newtype(type)
        raise "Type.newtype called, but I don't know why"
        @@typeary.push(type)
        if @@typehash.has_key?(type.name)
            Puppet.debug("Redefining object type %s" % type.name)
        end
        @@typehash[type.name] = type
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.type(type)
        unless @@typeary.length == @@typehash.length
            Type.buildtypehash
        end
        @@typehash[type]
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # class methods dealing with type instance management
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # retrieve a named object
    def Type.[](name)
        if @objects.has_key?(name)
            return @objects[name]
        else
            return nil
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.[]=(name,object)
        newobj = nil
        if object.is_a?(Puppet::Type)
            newobj = object
        else
            raise "must pass a Puppet::Type object"
        end

        if @objects.has_key?(newobj.name)
            #p @objects
            raise "Object '%s' of type '%s' already exists with id '%s' vs. '%s'" %
                [newobj.name,newobj.class.name,
                    @objects[newobj.name].object_id,newobj.object_id]
        else
            #Puppet.debug("adding %s of type %s to class list" %
            #    [object.name,object.class])
            @objects[newobj.name] = newobj
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # remove all type instances
    def Type.allclear
        @@typeary.each { |subtype|
            Puppet.debug "Clearing %s of objects" % subtype
            subtype.clear
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # per-type clearance
    def Type.clear
        if defined? @objects
            @objects.clear
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.each
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # all objects total
    def Type.push(object)
        @@allobjects.push object
        #Puppet.debug("adding %s of type %s to master list" %
        #    [object.name,object.class])
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # some simple stuff to make it easier to get a name from everyone
    def Type.namevar
        unless defined? @namevar and ! @namevar.nil?
            raise "Class %s has no namevar defined" % self
        end
        return @namevar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.has_key?(name)
        return @objects.has_key?(name)
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # class and instance methods dealing with parameters and states
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.buildstatehash
        unless defined? @validstates
            @validstates = Hash.new(false)
        end
        @states.each { |stateklass|
            name = stateklass.name
            if @validstates.include?(name) 
                if @validstates[name] != stateklass
                    raise "Redefining state %s(%s) in %s" % [name,stateklass,self]
                else
                    # it's already there, so don't bother
                end
            else
                @validstates[name] = stateklass
            end
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # Is the parameter in question a meta-parameter?
    def Type.metaparam(param)
        @@metaparams.include?(param)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this is probably only used by FileRecord objects
    def Type.parameters=(params)
        Puppet.debug "setting parameters to [%s]" % params.join(" ")
        @parameters = params.collect { |param|
            if param.class == Symbol
                param
            else
                param.intern
            end
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.states
        return @states
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.validstates
        return @validstates
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.validstate(name)
        unless @validstates.length == @states.length
            self.buildstatehash
        end
        if @validstates.include?(name)
            return @validstates[name]
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def Type.validparameter(name)
        unless defined? @parameters
            raise "Class %s has not defined parameters" % self
        end
        return @parameters.include?(name)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this abstracts accessing parameters and states, and normalizes
    # access to always be symbols, not strings
    # XXX this returns a _value_, not an object
    # if you want a state object, use <type>.state(<state>)
    def [](name)
        if name.is_a?(String)
            name = name.intern
        end

        if self.class.validstate(name)
            if @states.include?(name)
                return @states[name].is
            else
                return nil
            end
        elsif self.class.validparameter(name)
            if @parameters.include?(name)
                return @parameters[name]
            else
                return nil
            end
        else
            raise TypeError.new("Invalid parameter %s" % [name])
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this abstracts setting parameters and states, and normalizes
    # access to always be symbols, not strings
    def []=(name,value)
        mname = name
        if name.is_a?(String)
            mname = name.intern
        end

        if Puppet::Type.metaparam(mname)
            # call the metaparam method 
            self.send(("meta" + mname.id2name),value)
        elsif stateklass = self.class.validstate(mname) 
            if value.is_a?(Puppet::State)
                Puppet.debug "'%s' got handed a state for '%s'" % [self,mname]
                @states[mname] = value
            else
                if @states.include?(mname)
                    @states[mname].should = value
                else
                    #Puppet.warning "Creating state %s for %s" %
                    #    [stateklass.name,self.name]
                    @states[mname] = stateklass.new(
                        :parent => self,
                        :should => value
                    )
                    #Puppet.debug "Adding parent to %s" % mname
                    #@states[mname].parent = self
                end
            end
        elsif self.class.validparameter(mname)
            @parameters[mname] = value
        else
            raise "Invalid parameter %s" % [mname]
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # removing states
    def delete(attr)
        if @states.has_key?(attr)
            @states.delete(attr)
        else
            raise "Undefined state '#{attr}' in #{self}"
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def state(name)
        return @states[name]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def parameter(name)
        return @parameters[name]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # instance methods related to instance intrinsics
    # e.g., initialize() and name()
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def initialize(hash)
        @children = []
        @evalcount = 0

        @subscriptions = []

        # states and parameters are treated equivalently from the outside:
        # as name-value pairs (using [] and []=)
        # internally, however, parameters are merely a hash, while states
        # point to State objects
        # further, the lists of valid states and parameters are defined
        # at the class level
        @states = Hash.new(false)
        @parameters = Hash.new(false)

        @noop = false

        # which objects to notify when we change
        @notify = []

        # keeping stats for the total number of changes, and how many were
        # completely sync'ed
        # this isn't really sufficient either, because it adds lots of special cases
        # such as failed changes
        # it also doesn't distinguish between changes from the current transaction
        # vs. changes over the process lifetime
        @totalchanges = 0
        @syncedchanges = 0
        @failedchanges = 0

        hash.each { |var,value|
            unless var.is_a? Symbol
                hash[var.intern] = value
                hash.delete(var)
            end
        }

        if hash.include?(:noop)
            @noop = hash[:noop]
            hash.delete(:noop)
        end

        self.nameclean(hash)

        hash.each { |param,value|
            #Puppet.debug("adding param '%s' with value '%s'" %
            #    [param,value])
            self[param] = value
        }

        # add this object to the specific class's list of objects
        #puts caller
        self.class[self.name] = self

        # and then add it to the master list
        Puppet::Type.push(self)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return the full path to us, for logging and rollback
    # some classes (e.g., FileTypeRecords) will have to override this
    def fqpath
        return self.class, self.name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this might result from a state or from a parameter
    def name
        return self[self.class.namevar]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # fix any namevar => param translations
    def nameclean(hash)
        # we have to set the name of our object before anything else,
        # because it might be used in creating the other states
        namevar = self.class.namevar

        # if they're not using :name for the namevar but we got :name (probably
        # from the parser)
        if namevar != :name and hash.include?(:name) and ! hash[:name].nil?
            self[namevar] = hash[:name]
            hash.delete(:name)
        # else if we got the namevar
        elsif hash.has_key?(namevar) and ! hash[namevar].nil?
            self[namevar] = hash[namevar]
            hash.delete(namevar)
        # else something's screwy
        else
            raise TypeError.new("A name must be provided to %s at initialization time" %
                self.class)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def retrieve
        # it's important to use the method here, so we always get
        # them back in the right order
        self.states.collect { |state|
            state.retrieve
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def sync
        events = self.collect { |child|
            child.sync
        }.reject { |event|
            ! (event.is_a?(Symbol) or event.is_a?(String))
        }.flatten

        Puppet::Metric.addevents(self.class,self,events)
        return events
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        self.name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # instance methods dealing with contained states
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def managed
        if defined? @managed
            return @managed
        else
            @managed = false
            self.states.each { |state|
                if state.should
                    @managed = true
                end
            }
            return @managed
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def states
        Puppet.debug "%s has %s states" % [self,@states.length]
        tmpstates = []
        self.class.states.each { |state|
            if @states.include?(state.name)
                tmpstates.push(@states[state.name])
            end
        }
        unless tmpstates.length == @states.length
            raise "Something went very wrong with tmpstates creation"
        end
        return tmpstates
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def eachstate
        self.states.each { |state|
            yield state
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # iterate across all children, and then iterate across states
    # we do children first so we're sure that all dependent objects
    # are checked first
    # we ignore parameters here, because they only modify how work gets
    # done, they don't ever actually result in work specifically
    def each
        # we want to return the states in the order that each type
        # specifies it, because it may (as in the case of File#create)
        # be important
        @children.each { |child|
            yield child
        }
        self.eachstate { |state|
            yield state
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def push(*child)
        @children.push(*child)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # instance methods dealing with actually doing work
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def newchange
        @totalchanges += 1
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
        unless defined? @evalcount
            Puppet.err "No evalcount defined on '%s' of type '%s'" %
                [self.name,self.class]
        end
        # if we're a metaclass and we've already evaluated once...
        if self.metaclass and @evalcount > 0
            return
        end
        @evalcount += 1

        changes = @children.collect { |child|
            child.evaluate
        }

        # this only operates on states, not states + children
        self.retrieve
        unless self.insync?
            # add one to the number of out-of-sync instances
            Puppet::Metric.add(self.class,self,:outofsync,1)
            changes << self.states.find_all { |state|
                ! state.insync?
            }.collect { |state|
                Puppet::StateChange.new(state)
            }
        end
        # collect changes and return them
        # these changes could be from child objects or from contained states
        #self.collect { |child|
        #    child.evaluate
        #}

        # now record how many changes we've resulted in
        Puppet::Metric.add(self.class,self,:changes,changes.length)
        return changes.flatten
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # if all contained objects are in sync, then we're in sync
    def insync?
        insync = true

        self.states.each { |state|
            unless state.insync?
                Puppet.debug("%s is not in sync" % state)
                insync = false
            end
        }

        Puppet.debug("%s sync status is %s" % [self,insync])
        return insync
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # do we actually do work, or do we modify the system instead?
    # instances of a metaclass only get executed once per client process,
    # while instances of normal classes get run every time
    def metaclass
        return self.class.metaclass
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # Meta-parameter methods:  These methods deal with the results
    # of specifying metaparameters
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this just marks states that we definitely want to retrieve values
    # on
    def metacheck(args)
        unless args.is_a?(Array)
            args = [args]
        end

        # these are states that we might not have values for but we want to retrieve
        # values for anyway
        args.each { |state|
            unless state.is_a?(Symbol)
                state = state.intern
            end
            next if @states.include?(state)

            stateklass = nil
            unless stateklass = self.class.validstate(state)
                raise "%s is not a valid state for %s" % [state,self.class]
            end

            # XXX it's probably a bad idea to have code this important in
            # two places
            @states[state] = stateklass.new(
                :parent => self
            )
            #@states[state] = stateklass.new()
            #@states[state].parent = self
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def subscribe(hash)
        if hash[:event] == '*'
            hash[:event] = :ALL_EVENTS
        end

        hash[:source] = self
        sub = Puppet::Event::Subscription.new(hash)

        # add to the correct area
        @subscriptions.push sub
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return all of the subscriptions to a given event
    def subscribers?(event)
        @subscriptions.find_all { |sub|
            sub.event == event.event or
                sub.event == :ALL_EVENTS
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for each object we require, subscribe to all events that it
    # generates
    # we might reduce the level of subscription eventually, but for now...
    def metarequire(requires)
        unless requires.is_a?(Array)
            requires = [requires]
        end
        requires.each { |rname|
            # we just have a name and a type, and we need to convert it
            # to an object...
            type = nil
            object = nil
            tname = rname[0]
            unless type = Puppet::Type.type(tname)
                raise "Could not find type %s" % tname
            end
            name = rname[1]
            unless object = type[name]
                raise "Could not retrieve object '%s' of type '%s'" %
                    [name,type]
            end
            Puppet.debug("%s requires %s" % [self.name,object])

            # for now, we only support this one method, 'refresh'
            object.subscribe(
                :event => '*',
                :target => self,
                :method => :refresh
            )
            #object.addnotify(self)
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def metaonerror(response)
        Puppet.debug("Would have called metaonerror")
        @onerror = response
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def metaschedule(schedule)
        @schedule = schedule
    end
    #---------------------------------------------------------------
end # Puppet::Type
end

require 'puppet/type/service'
require 'puppet/type/exec'
require 'puppet/type/pfile'
require 'puppet/type/symlink'
require 'puppet/type/package'
require 'puppet/type/component'
require 'puppet/statechange'
#require 'puppet/type/typegen'
#require 'puppet/type/typegen/filetype'
#require 'puppet/type/typegen/filerecord'
