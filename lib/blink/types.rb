#!/usr/local/bin/ruby -w

# $Id$

# included so we can test object types
require 'blink/state'

# this is our base class
require 'blink/interface'

#---------------------------------------------------------------
# This class is the abstract base class for the mechanism for organizing
# work.  No work is actually done by this class or its subclasses; rather,
# the subclasses include states which do the actual work.
#   See state.rb for how work is actually done.

module Blink
	class Types < Blink::Interface
        include Enumerable
		@objects = Hash.new
		@@allobjects = Array.new # and then an array for all objects


        @@typeary = []
		@@typehash = Hash.new { |hash,key|
            raise "Object type %s not found" % key
        }

		#---------------------------------------------------------------
		# the class methods

		#-----------------------------------
		# all objects total
		def Types.push(object)
			@@allobjects.push object
			#Blink.debug("adding %s of type %s to master list" %
            #    [object.name,object.class])
		end
		#-----------------------------------

		#-----------------------------------
        # this is meant to be run multiple times, e.g., when a new
        # type is defined at run-time
        def Types.buildtypehash
            @@typeary.each { |otype|
                if @@typehash.include?(otype.name)
                    if @@typehash[otype.name] != otype
                        Blink.warning("Object type %s is already defined" % otype.name)
                    end
                else
                    @@typehash[otype.name] = otype
                end
            }
        end
		#-----------------------------------

		#-----------------------------------
        # this should make it so our subclasses don't have to worry about
        # defining these class instance variables
		def Types.inherited(sub)
            sub.module_eval %q{
                @objects = Hash.new
                @actions = Hash.new
            }

            # add it to the master list
            # unfortunately we can't yet call sub.name, because the #inherited
            # method gets called before any commands in the class definition
            # get executed, which, um, sucks
            @@typeary.push(sub)
		end
		#-----------------------------------

		#-----------------------------------
        # this is used for mapping object types (e.g., Blink::Types::File)
        # to names (e.g., "file")
        def Types.name
            return @name
        end
		#-----------------------------------

		#-----------------------------------
		# some simple stuff to make it easier to get a name from everyone
		def Types.namevar
			return @namevar
		end
		#-----------------------------------

		#-----------------------------------
		# accessor for the list of acceptable params
		def Types.classparams
			return @params
		end
		#-----------------------------------

		#-----------------------------------
		# our param list is by class, so we need to convert it to names
        # (see blink/objects/file.rb for an example of how params are defined)
		def Types.classparambyname
            unless defined? @paramsbyname
                @paramsbyname = Hash.new { |hash,key|
                    fail TypeError.new(
                        "Parameter %s is invalid for class %s" %
                        [key.to_s,self]
                    )
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
		#-----------------------------------

		#---------------------------------------------------------------
		# the instance methods

		#-----------------------------------
		# parameter access and stuff
		def [](param)
			if @states.has_key?(param)
				return @states[param].should
			else
				raise "Undefined parameter '#{param}' in #{self}"
			end
		end
		#-----------------------------------

		#-----------------------------------
        # because all object parameters are actually states, we
        # have to do some shenanigans to make it look from the outside
        # like @states is just a simple hash
        # the Symbol stuff is especially a bit hackish
        def []=(param,value)
            if @states.has_key?(param)
                @states[param].should = value
                return
            end

            attrclass = self.class.classparambyname[param]

            #Blink.debug("creating state of type '%s'" % attrclass)
            # any given object can normally only have one of any given state
            # type, but it might have many Symbol states 
            #
            # so, we need to make sure that the @states hash behaves
            # the same whether it has a unique state or a bunch of Symbol
            # states
            if attrclass.is_a?(Blink::State::Symbol)
                attrclass.should = value
                @states[param] = attrclass
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
		#-----------------------------------

		#-----------------------------------
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
		#-----------------------------------

		#-----------------------------------
		# removing states
		def delete(attr)
			if @states.has_key?(attr)
				@states.delete(attr)
			else
				raise "Undefined state '#{attr}' in #{self}"
			end
		end
		#-----------------------------------

		#-----------------------------------
        # XXX this won't work -- too simplistic
        # a given object can be in multiple components
        # which means... what? that i have to delete things from components?
        # that doesn't seem right, somehow...
        # do i really ever need to delete things?
        #def delete
        #    self.class.delete[self.name]
        #end
		#-----------------------------------

		#-----------------------------------
		# this can only be used with blocks that are
		# valid on operations and objects, as it iterates over both of
		# them
		# essentially, the interface defined by Blink::Interface is used here
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
		#-----------------------------------

		#-----------------------------------
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
		#-----------------------------------

		#-----------------------------------
		# store the object that immediately encloses us
		def enclosedby(obj)
			@enclosedby.push(obj)
		end
		#-----------------------------------

		#-----------------------------------
		def enclosed?
			defined? @enclosedby
		end
		#-----------------------------------

		#-----------------------------------
		# store a enclosed object
		def encloses(obj)
			obj.enclosedby(self)
			#obj.subscribe(self,'*')
			@encloses.push(obj)
		end
		#-----------------------------------

		#-----------------------------------
        # this is a wrapper, doing all of the work that should be done
        # and none that shouldn't
        def evaluate
            raise "don't call evaluate; it's disabled"
        end
		#-----------------------------------

		#-----------------------------------
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
		#-----------------------------------

		#-----------------------------------
		# yay
		def initialize(*args)
            # params are for classes, states are for instances
            # hokey but true
			@states = Hash.new
            @monitor = Array.new

            # default to always syncing
            @performoperation = :sync

            begin
                hash = Hash[*args]
            rescue ArgumentError
                fail TypeError.new("Incorrect number of arguments for %s" %
                    self.class.to_s)
            end

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
            Blink::Types.push(self)

			@notify = Hash.new
			#@encloses = Array.new
			#@enclosedby = Array.new
			@actions = Hash.new
			#@opsgenned = false

			# XXX i've no idea wtf is going on with enclosures
			#if self.class == Blink::Types::Root
			#	Blink.debug "not enclosing root (#{self.class}) in self"
			#else
			#	Blink::Types.root.encloses(self)
			#end
		end
		# initialize
		#-----------------------------------

		#-----------------------------------
		def name
            #namevar = self.class.namevar
            #Blink.debug "namevar is '%s'" % namevar
            #nameattr = @states[namevar]
            #Blink.debug "nameattr is '%s'" % nameattr
			#name = nameattr.value
            #Blink.debug "returning %s from attr %s and namevar %s" % [name,nameattr,namevar]
			#return name
			return @states[self.class.namevar].is
		end
		#-----------------------------------

		#-----------------------------------
		def newevent(args)
			if args[:event].nil?
				raise "newevent called wrong on #{self}"
			end

			return Blink::Event.new(
				:event => args[:event],
				:object => self
			)
		end
		#-----------------------------------

		#-----------------------------------
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
		#-----------------------------------

		#-----------------------------------
		def to_s
			self.name
		end
		#-----------------------------------

		#-----------------------------------
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
		#-----------------------------------

		#-----------------------------------
        def validparam(param)
            if (self.class.operparams.include?(param) or
                self.class.staticparams.include?(param))
                return true
            else
                return false
            end
        end
		#-----------------------------------

		#---------------------------------------------------------------
	end # Blink::Types
end
