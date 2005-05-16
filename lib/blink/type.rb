#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'blink'
require 'blink/element'
require 'blink/type/state'


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
# although states don't inherit from Blink::Type
#   although maybe Blink::State should...

# the default behaviour that this class provides is to just call a given
# method on each contained object, e.g., in calling 'sync', we just run:
# object.each { |subobj| subobj.sync() }

# to use this interface, just define an 'each' method and 'include Blink::Type'

module Blink
class Blink::Type < Blink::Element
    attr_accessor :children, :parameters, :parent, :states
    include Enumerable

    @@allobjects = Array.new # an array for all objects
    @abstract = true

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
    @@typeary = []
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
    # this is meant to be run multiple times, e.g., when a new
    # type is defined at run-time
    def Type.buildtypehash
        @@typeary.each { |otype|
            if @@typehash.include?(otype.name)
                if @@typehash[otype.name] != otype
                    Blink.warning("Object type %s is already defined (%s vs %s)" %
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

        Blink.debug("subtype %s just created" % sub)
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
        @validstates = {}
        @validparameters = {}
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
    # this is used for mapping object types (e.g., Blink::Type::File)
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
            Blink.notice("Redefining object type %s" % type.name)
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
        if object.is_a?(Blink::Type)
            newobj = object
        else
            raise "must pass a Blink::Type object"
        end

        if @objects.has_key?(newobj.name)
            puts @objects
            raise "Object '%s' of type '%s' already exists" %
                [newobj.name,newobj.class.name]
        else
            #Blink.debug("adding %s of type %s to class list" %
            #    [object.name,object.class])
            @objects[newobj.name] = newobj
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # all objects total
    def Type.push(object)
        @@allobjects.push object
        #Blink.debug("adding %s of type %s to master list" %
        #    [object.name,object.class])
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # some simple stuff to make it easier to get a name from everyone
    def Type.namevar
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
    def Type.states
        return @states
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
        return @parameters.include?(name)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this abstracts accessing parameters and states, and normalizes
    # access to always be symbols, not strings
    def [](name)
        mname = name
        if name.is_a?(String)
            mname = name.intern
        end
        if @states.include?(mname)
            # if they're using [], they don't know if we're a state or a string
            # thus, return a string
            # if they want the actual state object, they should use state()
            return @states[mname].is
        elsif @parameters.include?(mname)
            return @parameters[mname]
        else
            raise "Invalid parameter %s%s" % [mname]
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

        if stateklass = self.class.validstate(mname) 
            if value.is_a?(Blink::State)
                @states[mname] = value
            else
                if @states.include?(mname)
                    @states[mname].should = value
                else
                    @states[mname] = stateklass.new(value)
                    @states[mname].parent = self
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

        @parent = nil
        @noop = false

        # these are not currently used
        @monitor = Array.new
        @notify = Hash.new
        @actions = Hash.new

        # if they passed in a list of states they're interested in,
        # we mark them as "interesting"
        # XXX maybe we should just consider params set to nil as 'interesting'
        #
        # this isn't used as much as it should be, but the idea is that
        # the "interesting" states would be the ones retrieved during a
        # 'retrieve' call
        if hash.include?(:check)
            @monitor = hash[:check].dup
            hash.delete(:check)
        end

        if hash.include?("noop")
            @noop = hash["noop"]
            hash.delete("noop")
        end

        # states and parameters are treated equivalently from the outside:
        # as name-value pairs (using [] and []=)
        # internally, however, parameters are merely a hash, while states
        # point to State objects
        # further, the lists of valid states and parameters are defined
        # at the class level
        @states = Hash.new(false)
        @parameters = Hash.new(false)

        # we have to set the name of our object before anything else,
        # because it might be used in creating the other states
        if hash.has_key?(self.class.namevar)
            self[self.class.namevar] = hash[self.class.namevar]
            #Blink.notice("%s: namevar [%s], hash name [%s], name [%s], name2 [%s]" %
            #    [self.class,self.class.namevar,hash[self.class.namevar],self.name,self[self.class.namevar]])
            hash.delete(self.class.namevar)
        else
            p hash
            p self.class.namevar
            raise TypeError.new("A name must be provided to %s at initialization time" %
                self.class)
        end

        hash.each { |param,value|
            @monitor.push(param)
            #Blink.debug("adding param '%s' with value '%s'" %
            #    [param,value])
            self[param] = value
        }

        # add this object to the specific class's list of objects
        #Blink.notice("Adding [%s] to %s" % [self.name,self.class])
        self.class[self.name] = self

        # and then add it to the master list
        Blink::Type.push(self)
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
    # iterate across all children, and then iterate across states
    # we do children first so we're sure that all dependent objects
    # are checked first
    # we ignore parameters here, because they only modify how work gets
    # done, they don't ever actually result in work specifically
    def each
        # we want to return the states in the order that each type
        # specifies it, because it may (as in the case of File#create)
        # be important
        tmpstates = []
        self.class.states.each { |state|
            if @states.include?(state.name)
                tmpstates.push(@states[state.name])
            end
        }
        unless tmpstates.length == @states.length
            raise "Something went very wrong with tmpstates creation"
        end
        [@children,tmpstates].flatten.each { |child|
            yield child
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
    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
        # if we're a metaclass and we've already evaluated once...
        if self.metaclass and @evalcount > 0
            return
        end
        @evalcount += 1
        # these might return messages, but the main action is through
        # setting changes in the transactions
        self.collect { |child|
            child.evaluate
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # if all contained objects are in sync, then we're in sync
    def insync?
        insync = true

        self.each { |obj|
            unless obj.insync?
                Blink.debug("%s is not in sync" % obj)
                insync = false
            end
        }

        Blink.debug("%s sync status is %s" % [self,insync])
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
    # this method is responsible for handling changes in dependencies
    # for instance, restarting a service if a config file is changed
    # in general, we just hand the method up to our parent, but for
    # objects that might need to refresh, they'll override this method
    # XXX at this point, if all dependent objects change, then this method
    # might get called for each change
    def refresh(transaction)
        unless @parent.nil?
            @parent.refresh(transaction)
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # set up the "interface" methods
    [:sync,:retrieve].each { |method|
        self.send(:define_method,method) {
            self.each { |subobj|
                #Blink.debug("sending '%s' to '%s'" % [method,subobj])
                subobj.send(method)
            }
        }
    }
    #---------------------------------------------------------------
end # Blink::Type
end

require 'blink/type/service'
require 'blink/type/file'
require 'blink/type/symlink'
require 'blink/type/package'
require 'blink/type/component'
require 'blink/statechange'
