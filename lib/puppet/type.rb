#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'puppet'
require 'puppet/element'
require 'puppet/event'
require 'puppet/metric'
require 'puppet/type/state'


# see the bottom of the file for the rest of the inclusions

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
    attr_accessor :file, :line
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

    #@paramdoc = Hash.new

    # the parameters that all instances will accept
    @@metaparams = [
        :onerror,
        :noop,
        :schedule,
        :check,
        :subscribe,
        :require
    ]

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

    @@metaparamdoc[:onerror] = "How to handle errors -- roll back innermost
        transaction, roll back entire transaction, ignore, etc.  Currently
        non-functional."
    @@metaparamdoc[:noop] = "Boolean flag indicating whether work should actually
        be done."
    @@metaparamdoc[:schedule] = "On what schedule the object should be managed.
        Currently non-functional."
    @@metaparamdoc[:check] = "States which should have their values retrieved
        but which should not actually be modified.  This is currently used
        internally, but will eventually be used for querying."
    @@metaparamdoc[:require] = "One or more objects that this object depends on.
        This is used purely for guaranteeing that changes to required objects
        happen before the dependent object."
    @@metaparamdoc[:subscribe] = "One or more objects that this object depends on.
        Changes in the subscribed to objects result in the dependent objects being
        refreshed (e.g., a service will get restarted)."
   
    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # class methods dealing with Type management
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    public

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
            raise TypeError.new("Object type %s not found" % key)
        end
    }

    # the Type class attribute accessors
    class << self
        attr_reader :name, :namevar, :states, :validstates, :parameters
    end

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # iterate across all of the subclasses of Type
    def self.eachtype
        @@typeary.each { |type| yield type }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return a Type instance by name
    def self.type(type)
        unless @@typeary.length == @@typehash.length
            # call bulidtypehash if types have been added since it
            # was last called
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

    public

    #---------------------------------------------------------------
    # retrieve a named instance of the current type
    def self.[](name)
        if @objects.has_key?(name)
            return @objects[name]
        else
            return nil
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # add an instance by name to the class list of instances
    def self.[]=(name,object)
        newobj = nil
        if object.is_a?(Puppet::Type)
            newobj = object
        else
            raise "must pass a Puppet::Type object"
        end

        if @objects.has_key?(newobj.name)
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
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # remove all type instances; this is mostly only useful for testing
    def self.allclear
        @@allobjects.clear
        @@typeary.each { |subtype|
            subtype.clear
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # remove all of the instances of a single type
    def self.clear
        if defined? @objects
            @objects.clear
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # iterate across each of the type's instances
    def self.each
        return unless defined? @objects
        @objects.each { |name,instance|
            yield instance
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # does the type have an object with the given name?
    def self.has_key?(name)
        return @objects.has_key?(name)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # add an object to the master list of Type instances
    # I'm pretty sure this is currently basically unused
    def self.push(object)
        @@allobjects.push object
        #debug("adding %s of type %s to master list" %
        #    [object.name,object.class])
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # class and instance methods dealing with parameters and states
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    public

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # set the parameters for a type; probably only used by FileRecord
    # objects
    def self.parameters=(params)
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # does the name reflect a valid parameter?
    def self.validparameter?(name)
        unless defined? @parameters
            raise Puppet::DevError, "Class %s has not defined parameters" % self
        end
        if @parameters.include?(name) or @@metaparams.include?(name)
            return true
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def self.validarg?(name)
        if name.is_a?(String)
            name = name.intern
        end
        if self.validstate?(name) or self.validparameter?(name) or self.metaparam?(name)
            return true
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # abstract accessing parameters and states, and normalize
    # access to always be symbols, not strings
    # XXX this returns a _value_, not an object
    # if you want a state object, use <type>.state(<state>)
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
        elsif self.class.validparameter?(name)
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
    # abstract setting parameters and states, and normalize
    # access to always be symbols, not strings
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
            @parameters[name] = value
            # call the metaparam method 
            self.send(("meta" + name.id2name + "="),value)
        elsif stateklass = self.class.validstate?(name) 
            if value.is_a?(Puppet::State)
                Puppet.debug "'%s' got handed a state for '%s'" % [self,name]
                @states[name] = value
            else
                if @states.include?(name)
                    @states[name].should = value
                else
                    #Puppet.warning "Creating state %s for %s" %
                    #    [stateklass.name,self.name]
                    begin
                        # make sure the state doesn't have any errors
                        newstate = stateklass.new(
                            :parent => self,
                            :should => value
                        )
                        @states[name] = newstate
                    rescue Puppet::Error => detail
                        # the state failed, so just ignore it
                        Puppet.warning "State %s failed: %s" %
                            [name, detail]
                    rescue Puppet::DevError => detail
                        # the state failed, so just ignore it
                        Puppet.err "State %s failed: %s" %
                            [name, detail]
                    rescue => detail
                        # the state failed, so just ignore it
                        Puppet.err "State %s failed: %s (%s)" %
                            [name, detail, detail.class]
                    end
                end
            end
        elsif self.class.validparameter?(name)
            # if they've got a method to handle the parameter, then do it that way
            method = "param" + name.id2name + "="
            if self.respond_to?(method)
                self.send(method,value)
            else
                # else just set it
                @parameters[name] = value
            end
        else
            raise "Invalid parameter %s" % [name]
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # remove a state from the object; useful in testing or in cleanup
    # when an error has been encountered
    def delete(attr)
        if @states.has_key?(attr)
            @states.delete(attr)
        else
            raise Puppet::DevError.new("Undefined state '#{attr}' in #{self}")
        end
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # iterate across the existing states
    def eachstate
        # states() is a private method
        states().each { |state|
            yield state
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # retrieve the 'is' value for a specified state
    def is(state)
        if @states.include?(state)
            return @states[state].is
        else
            return nil
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # retrieve the 'should' value for a specified state
    def should(state)
        if @states.include?(state)
            return @states[state].should
        else
            return nil
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return the value of a parameter
    def parameter(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @parameters[name]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def push(*childs)
        unless defined? @children
            @children = []
        end
        childs.each { |child|
            @children.push(child)
            child.parent = self
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return an actual type by name; to return the value, use 'inst[name]'
    # FIXME this method should go away
    def state(name)
        unless name.is_a? Symbol
            name = name.intern
        end
        return @states[name]
    end
    #---------------------------------------------------------------

    private

    #---------------------------------------------------------------
    def states
        #debug "%s has %s states" % [self,@states.length]
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
    #---------------------------------------------------------------
    # instance methods related to instance intrinsics
    # e.g., initialize() and name()
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    public

    #---------------------------------------------------------------
    # initialize the type instance
    def initialize(hash)
        @children = []
        @evalcount = 0

        @subscriptions = []
        @dependencies = []

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

        #unless defined? @paramdoc
        #   @paramdoc = Hash.new { |hash,key|
        #      if key.is_a?(String)
        #         key = key.intern
        #      end
        #      if hash.include?(key)
        #         hash[key]
        #      else
        #         "Param Documentation for %s not found" % key
        #      end
        #   }
        #end

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

        hash = self.argclean(hash)

        # now get all of the arguments, in a specific order
        order = [self.class.namevar]
        order << [self.class.states.collect { |state| state.name },
            self.class.parameters,
            self.class.eachmetaparam { |param| param }].flatten.reject { |param|
                # we don't want our namevar in there multiple times
                param == self.class.namevar
        }

        order.flatten.each { |name|
            if hash.include?(name)
                begin
                    self[name] = hash[name]
                rescue => detail
                    raise Puppet::DevError.new( 
                        "Could not set %s on %s: %s" % [name, self.class, detail]
                    )
                end
                hash.delete name
            end
        }

        if hash.length > 0
            Puppet.debug hash.inspect
            raise Puppet::Error.new("Class %s does not accept argument(s) %s" %
                [self.class.name, hash.keys.join(" ")])
        end

        # add this object to the specific class's list of objects
        #puts caller
        self.class[self.name] = self

        # and then add it to the master list
        Puppet::Type.push(self)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # derive the instance name based on class.namevar
    def name
        unless defined? @name and @name
            namevar = self.class.namevar
            if self.class.validparameter?(namevar)
                @name = @parameters[namevar]
            elsif self.class.validstate?(namevar)
                @name = self.should(namevar)
            else
                raise Puppet::DevError, "Could not find namevar %s for %s" %
                    [namevar, self.class.name]
            end
        end

        unless @name
            raise Puppet::DevError, "Could not find name %s for %s" %
                [namevar, self.class.name]
        end

        return @name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # fix any namevar => param translations
    def argclean(hash)
        # we have to set the name of our object before anything else,
        # because it might be used in creating the other states
        hash = hash.dup
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return the full path to us, for logging and rollback
    # some classes (e.g., FileTypeRecords) will have to override this
    def path
        if defined? @parent
            return [@parent.path, self.name].flatten
        else
            return [self.name]
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # retrieve the current value of all contained states
    def retrieve
        # it's important to use the method here, as it follows the order
        # in which they're defined in the object
        states.each { |state|
            state.retrieve
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # sync the changes to disk, and return the events generated by the changes
    # FIXME this method is essentially obviated, but it's still used by tests
    # and i don't feel like fixing it yet
    def sync
        #raise Puppet::DevError, "Type#sync called"
        events = self.collect { |child|
            child.sync
        }.reject { |event|
            ! (event.is_a?(Symbol) or event.is_a?(String))
        }.flatten

        Puppet.notice "got events %s" % events.inspect

        Puppet::Metric.addevents(self.class,self,events)
        return events
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # convert to a string
    def to_s
        self.name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # instance methods dealing with actually doing work
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    public

    #---------------------------------------------------------------
    # this is a retarded hack method to get around the difference between
    # component children and file children
    def self.depthfirst?
        if defined? @depthfirst
            return @depthfirst
        else
            return false
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
        #Puppet.err "Evaluating %s" % self.path.join(":")
        unless defined? @evalcount
            Puppet.err "No evalcount defined on '%s' of type '%s'" %
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
            Puppet.info "%s: %s change(s)" %
                [self.name, changes.length]
            #changes.each { |change|
            #    Puppet.debug "change: %s" % change.state.name
            #}
        end
        return changes.flatten
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more
    def insync?
        insync = true

        states.each { |state|
            unless state.insync?
                #Puppet.debug("%s is not in sync" % state)
                insync = false
            end
        }

        #Puppet.debug("%s sync status is %s" % [self,insync])
        return insync
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # Meta-parameter methods:  These methods deal with the results
    # of specifying metaparameters
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def self.eachmetaparam
        @@metaparams.each { |param|
            yield param
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # This just marks states that we definitely want to retrieve values
    # on.  There is currently no way to uncheck a parameter.
    def metacheck=(args)
        unless args.is_a?(Array)
            args = [args]
        end

        # these are states that we might not have 'should'
        # values for but we want to retrieve 'is' values for anyway
        args.each { |state|
            unless state.is_a?(Symbol)
                state = state.intern
            end
            next if @states.include?(state)

            stateklass = nil
            unless stateklass = self.class.validstate?(state)
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
    # Is the parameter in question a meta-parameter?
    def self.metaparam?(param)
        @@metaparams.include?(param)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for each object we require, subscribe to all events that it
    # generates
    # we might reduce the level of subscription eventually, but for now...
    def metarequire=(requires)
        self.handledepends(requires, :NONE, nil)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for each object we require, subscribe to all events that it
    # generates
    # we might reduce the level of subscription eventually, but for now...
    def metasubscribe=(requires)
        self.handledepends(requires, :ALL_EVENTS, :refresh)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def metanoop=(noop)
        if noop == "true" or noop == true
            @noop = true
        elsif noop == "false" or noop == false
            @noop = false
        else
            raise Puppet::Error.new("Invalid noop value '%s'" % noop)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def metaonerror=(response)
        Puppet.debug("Would have called metaonerror")
        @onerror = response
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def metaschedule=(schedule)
        @schedule = schedule
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # Subscription and relationship methods
    #---------------------------------------------------------------
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def addcallback(object, event, method)
        @callbacks[object][event] = method
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return all objects subscribed to the current object
    def eachdependency
        @dependencies.each { |dep|
            yield dep
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # return all objects subscribed to the current object
    def eachsubscriber
        @subscriptions.each { |sub|
            yield sub.target
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def handledepends(requires, event, method)
        # FIXME this should probably test whether requires[0] is an array
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
                raise Puppet::Error, "Could not find type %s" % tname
            end
            name = rname[1]
            unless object = type[name]
                raise Puppet::Error, "Could not retrieve object '%s' of type '%s'" %
                    [name,type]
            end
            Puppet.debug("%s subscribes to %s" % [self.name,object])

            unless @dependencies.include?(object)
                @dependencies << object
            end

            # pure requires don't call methods
            next if method.nil?

            # ok, both sides of the connection store some information
            # we store the method to call when a given subscription is 
            # triggered, but the source object decides whether 
            sub = object.subscribe(
                :event => event,
                :target => self
            )
            if self.respond_to?(method)
                self.addcallback(object, event, method)
            end
            #object.addnotify(self)
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def propagate(event)
        self.subscribers?(event).each { |object|
            object.trigger(event, self)
        }

        if defined? @parent
            @parent.propagate(event)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def subscribe(hash)
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
        }.collect { |sub|
            sub.target
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
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
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #---------------------------------------------------------------
    # Documentation methods
    #---------------------------------------------------------------
    #---------------------------------------------------------------
    def self.paramdoc(param)
        @paramdoc[param]
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------
    def self.metaparamdoc(metaparam)
        @@metaparamdoc[metaparam]
    end
    #---------------------------------------------------------------
    #---------------------------------------------------------------
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
