#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
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
	class Type
        include Enumerable
        # this is a bit of a hack, but it'll work for now
        attr_accessor :performoperation
        attr_writer :noop

		@@allobjects = Array.new # an array for all objects

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
        # this is meant to be run multiple times, e.g., when a new
        # type is defined at run-time
        def Type.buildtypehash
            @@typeary.each { |otype|
                if @@typehash.include?(otype.name)
                    if @@typehash[otype.name] != otype
                        Blink.warning("Object type %s is already defined" %
                            otype.name)
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
				raise "Object '#{name}' does not exist"
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
				raise "'#{newobj.name}' already exists in " +
                    "class '#{newobj.class}': #{@objects[newobj.name]}"
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
		# class methods dealing with contained states
		#---------------------------------------------------------------
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# accessor for the list of acceptable params
		def Type.classparams
			return @params
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# our param list is by class, so we need to convert it to names
        # (see blink/objects/file.rb for an example of how params are defined)
		def Type.classparambyname
            unless defined? @paramsbyname
                @paramsbyname = Hash.new { |hash,key|
                    if key.is_a?(String)
                        key = key.intern
                    end
                    if hash.include?(key)
                        hash[key]
                    else
                        fail TypeError.new(
                            "Parameter %s is invalid for class %s" %
                            [key.to_s,self]
                        )
                    end
                }
                @params.each { |param|
                    if param.is_a? Symbol
                        # store the Symbol class, not the symbol itself
                        symbolattr = Blink::State::Symbol.new(param)

                        @paramsbyname[param] = symbolattr
                    elsif param.respond_to?(:name)
                        # these are already classes
                        @paramsbyname[param.name] = param
                    else
                        fail TypeError.new(
                            "Parameter %s is invalid; it must be a class or symbol" %
                            param.to_s
                        )
                    end
                }
            end
			return @paramsbyname
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		#---------------------------------------------------------------
		# instance methods related to instance intrinics
        # e.g., initialize() and name()
		#---------------------------------------------------------------
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# flesh out our instance
		def initialize(hash)
            # params are for classes, states are for instances
            # hokey but true
			@states = Hash.new
            @monitor = Array.new
			@notify = Hash.new
			#@encloses = Array.new
			#@enclosedby = Array.new
			@actions = Hash.new
			#@opsgenned = false

            # default to always syncing
            @performoperation = :sync

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

            # we have to set the name of our object before anything else,
            # because it might be used in creating the other states
            if hash.has_key?(self.class.namevar)
                self[self.class.namevar] = hash[self.class.namevar]
                hash.delete(self.class.namevar)
            else
                #p hash
                #p self.class.namevar
                raise TypeError.new("A name must be provided at initialization time")
            end

            hash.each { |param,value|
                @monitor.push(param)
                #Blink.debug("adding param '%s' with value '%s'" %
                #    [param,value])
                self[param] = value
            }

            # add this object to the specific class's list of objects
			self.class[name] = self

            # and then add it to the master list
            Blink::Type.push(self)

		end
		# initialize
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # return the full path to us, for logging and rollback
        # some classes (e.g., FileTypeRecords) will have to override this
        def fqpath
            return self.class, self.name
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		def name
			return @states[self.class.namevar].is
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
		# state access and stuff
		def [](state)
			if @states.has_key?(state)
				return @states[state]
			else
				raise "Undefined state '#{state}' in #{self}"
			end
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # because all object parameters are actually states, we
        # have to do some shenanigans to make it look from the outside
        # like @states is just a simple hash
        # the Symbol stuff is especially a bit hackish
        def []=(state,value)
            if @states.has_key?(state)
                @states[state].should = value
                return
            end

            attrclass = self.class.classparambyname[state]

            #Blink.debug("creating state of type '%s'" % attrclass)
            # any given object can normally only have one of any given state
            # type, but it might have many Symbol states 
            #
            # so, we need to make sure that the @states hash behaves
            # the same whether it has a unique state or a bunch of Symbol
            # states
            if attrclass.is_a?(Blink::State::Symbol)
                attrclass.should = value
                @states[state] = attrclass
            else
                attr = attrclass.new(value)
                attr.object = self
                if attr.is_a?(Array)
                    attr.each { |xattr|
                        @states[xattr.name] = attr
                    }
                else
                    Blink.debug "Creating attr %s in %s" % [attr.name,self]
                    @states[attr.name] = attr
                end
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
		# this can only be used with blocks that are
		# valid on operations and objects, as it iterates over both of
		# them
		# essentially, the interface defined by Blink::Type is used here
		def each
			ret = false
			nodepth = 0
			unless block_given?
				raise "'Each' was not given a block"
			end
            @states.each { |name,attr|
				#Blink.debug "'%s' yielding '%s' of type '%s'" % [self,attr,attr.class]
                yield(attr)
            }
            # DISABLED
            # until we're clear on what 'enclosure' means, this is
            # all disabled

			#if @encloses.length > 0
			#	Blink.debug "#{self} encloses #{@encloses}"
			##end
			#if defined? Blink['depthfirst']
			#	self.eachobj { |enclosed|
			#		Blink.debug "yielding #{self} to object #{enclosed}"
			#		ret |= yield(enclosed)
			#	}
			#	nodepth = 1
			#end
			#self.eachop { |op|
			#	Blink.debug "yielding #{self} to op #{op}"
			#	ret |= yield(op)
			#}
			#if ! defined? Blink['depthfirst'] and nodepth != 1
			#	self.eachobj { |enclosed|
			#		Blink.debug "yielding #{self} to object #{enclosed}"
			#		ret |= yield(enclosed)
			#	}
			#end
			#return ret
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		#---------------------------------------------------------------
		# instance methods dealing with actually doing work
		#---------------------------------------------------------------
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def evaluate
            self.retrieve
            unless self.insync?
                if @performoperation == :sync
                    self.sync
                else
                    # we, uh, don't do anything
                end
            end
            self.retrieve
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
        # should we actually do anything?
        def noop
            return self.noop || Blink[:noop] || false
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

		#---------------------------------------------------------------
        def presync
            self.each { |contained|
                # this gets right to the heart of our question:
                # do all subclasses of Type contain all of their
                # content in contained objects?
                Blink::Modification.new(contained)
            }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		#---------------------------------------------------------------
		# instance methods handling actions and enclosure
        # these are basically not used right now
		#---------------------------------------------------------------
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# return action array
		# these are actions to use for responding to events
		# no, this probably isn't the best way, because we're providing
        # access to the actual hash, which is silly
		def action
            if not defined? @actions
                puts "defining action hash"
                @actions = Hash.new
            end
			@actions
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# this allows each object to act like both a node and
		# a branch
		# but each object contains two types of objects: operations and other
		# objects....
		def eachobj
			unless block_given?
				raise "Eachobj was not given a block"
			end
			@encloses.each { |object|
				yield(object)
			}
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# store the object that immediately encloses us
		def enclosedby(obj)
			@enclosedby.push(obj)
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		def enclosed?
			defined? @enclosedby
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# store a enclosed object
		def encloses(obj)
			obj.enclosedby(self)
			#obj.subscribe(self,'*')
			@encloses.push(obj)
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# call an event
		# this is called on subscribers by the trigger method from the obj
		# which sent the event
		# event handling should probably be taking place in a central process,
		# but....
		def event(event,obj)
			Blink.debug "#{self} got event #{event} from #{obj}"
			if @actions.key?(event)
				Blink.debug "calling it"
				@actions[event].call(self,obj,event)
			else
				p @actions
			end
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		def newevent(args)
			if args[:event].nil?
				raise "newevent called wrong on #{self}"
			end

			return Blink::Event.new(
				:event => args[:event],
				:object => self
			)
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# subscribe to an event or all events
		# this entire event system is a hack job and needs to
		# be replaced with a central event handler
		def subscribe(args,&block)
			obj = args[:object]
			event = args[:event] || '*'.intern
			if obj.nil? or event.nil?
				raise "subscribe was called wrongly; #{obj} #{event}"
			end
			obj.action[event] = block
			#events.each { |event|
				unless @notify.key?(event)
					@notify[event] = Array.new
				end
				unless @notify[event].include?(obj)
					Blink.debug "pushing event '%s' for object '%s'" % [event,obj]
					@notify[event].push(obj)
				end
			#	}
			#else
			#	@notify['*'.intern].push(obj)
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# initiate a response to an event
		def trigger(event)
			subscribers = Array.new
			if @notify.include?('*') and @notify['*'].length > 0
				@notify['*'].each { |obj| subscribers.push(obj) }
			end
			if (@notify.include?(event) and (! @notify[event].empty?) )
				@notify[event].each { |obj| subscribers.push(obj) }
			end
			Blink.debug "triggering #{event}"
			subscribers.each { |obj|
				Blink.debug "calling #{event} on #{obj}"
				obj.event(event,self)
			}
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
	end # Blink::Type
end
require 'blink/type/service'
require 'blink/type/file'
require 'blink/type/symlink'
require 'blink/type/package'
require 'blink/component'
