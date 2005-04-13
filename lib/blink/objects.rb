#!/usr/local/bin/ruby -w

# $Id$

require 'blink/attribute'
require 'blink/interface'


module Blink
	class Objects < Blink::Interface
        include Enumerable
		@objects = Hash.new # a class instance variable
		@@allobjects = Array.new # and then a hash for all objects

		#---------------------------------------------------------------
		# the class methods

		#-----------------------------------
		# all objects total
		def Objects.push(object)
			@@allobjects.push object
			Blink.debug("adding %s of type %s to master list" % [object.name,object.class])
		end
		#-----------------------------------

		#-----------------------------------
        # this should make it so our subclasses don't have to worry about
        # defining these class instance variables
		def Objects.inherited(sub)
            sub.module_eval %q{
                @objects = Hash.new
                @actions = Hash.new
            }
		end
		#-----------------------------------

		#-----------------------------------
		# some simple stuff to make it easier to get a name from everyone
		def Objects.namevar
			return @namevar
		end
		#-----------------------------------

		#-----------------------------------
		# accessor for the list of acceptable params
		def Objects.classparams
			return @params
		end
		#-----------------------------------

		#-----------------------------------
		# our param list is by class, so we need to convert it to names
        # (see blink/objects/file.rb for an example of how params are defined)
		def Objects.classparambyname
            unless defined? @paramsbyname
                @paramsbyname = Hash.new { |hash,key|
                    fail TypeError.new(
                        "Parameter %s is invalid for class %s" %
                        [key.to_s,self.class.to_s]
                    )
                }
                @params.each { |param|
                    if param.is_a? Symbol
                        # store the Symbol class, not the symbol itself
                        symbolattr = Blink::Attribute::Symbol.new(param)

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
			if @attributes.has_key?(param)
				return @attributes[param].should
			else
				raise "Undefined parameter '#{param}' in #{self}"
			end
		end
		#-----------------------------------

		#-----------------------------------
        # because all object parameters are actually attributes, we
        # have to do some shenanigans to make it look from the outside
        # like @attributes is just a simple hash
        # the Symbol stuff is especially a bit hackish
        def []=(param,value)
            if @attributes.has_key?(param)
                @attributes[param].should = value
                return
            end

            attrclass = self.class.classparambyname[param]

            Blink.debug("creating attribute of type '%s'" % attrclass)
            # any given object can normally only have one of any given attribute
            # type, but it might have many Symbol attributes 
            #
            # so, we need to make sure that the @attributes hash behaves
            # the same whether it has a unique attribute or a bunch of Symbol
            # attributes
            if attrclass.is_a?(Blink::Attribute::Symbol)
                attrclass.should = value
                @attributes[param] = attrclass
            else
                attr = attrclass.new(value)
                attr.object = self
                if attr.is_a?(Array)
                    attr.each { |xattr|
                        @attributes[xattr.name] = attr
                    }
                else
                    Blink.debug "Creating attr %s in %s" % [attr.name,self]
                    @attributes[attr.name] = attr
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
		# removing attributes
		def delete(attr)
			if @attributes.has_key?(attr)
				@attributes.delete(attr)
			else
				raise "Undefined attribute '#{attr}' in #{self}"
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
            @attributes.each { |name,attr|
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
            # params are for classes, attributes are for instances
            # hokey but true
			@attributes = Hash.new
            @monitor = Array.new

            # default to always syncing
            @performoperation = :sync

            begin
                hash = Hash[*args]
            rescue ArgumentError
                fail TypeError.new("Incorrect number of arguments for %s" %
                    self.class.to_s)
            end

            # if they passed in a list of attributes they're interested in,
            # we mark them as "interesting"
            # XXX maybe we should just consider params set to nil as 'interesting'
            #
            # this isn't used as much as it should be, but the idea is that
            # the "interesting" attributes would be the ones retrieved during a
            # 'retrieve' call
            if hash.include?(:check)
                @monitor = hash[:check].dup
                hash.delete(:check)
            end

            # we have to set the name of our object before anything else,
            # because it might be used in creating the other attributes
            if hash.has_key?(self.class.namevar)
                self[self.class.namevar] = hash[self.class.namevar]
                hash.delete(self.class.namevar)
            else
                raise TypeError.new("A name must be provided at initialization time")
            end

            hash.each { |param,value|
                @monitor.push(param)
                Blink.debug("adding param '%s' with value '%s'" %
                    [param,value])
                self[param] = value
            }

            # add this object to the specific class's list of objects
			self.class[name] = self

            # and then add it to the master list
            Blink::Objects.push(self)

			@notify = Hash.new
			#@encloses = Array.new
			#@enclosedby = Array.new
			@actions = Hash.new
			#@opsgenned = false

			# XXX i've no idea wtf is going on with enclosures
			#if self.class == Blink::Objects::Root
			#	Blink.debug "not enclosing root (#{self.class}) in self"
			#else
			#	Blink::Objects.root.encloses(self)
			#end
		end
		# initialize
		#-----------------------------------

		#-----------------------------------
		def name
            #namevar = self.class.namevar
            #Blink.debug "namevar is '%s'" % namevar
            #nameattr = @attributes[namevar]
            #Blink.debug "nameattr is '%s'" % nameattr
			#name = nameattr.value
            #Blink.debug "returning %s from attr %s and namevar %s" % [name,nameattr,namevar]
			#return name
			return @attributes[self.class.namevar].value
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
	end # Blink::Objects
end
