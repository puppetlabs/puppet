#!/usr/local/bin/ruby -w

# $Id$

# our duck type interface -- if your object doesn't match this interface,
# it won't work

# all of our first-class objects (objects, states, and components) will
# respond to these methods
# although states don't inherit from Blink::Interface
#   although maybe Blink::State should...

# the default behaviour that this class provides is to just call a given
# method on each contained object, e.g., in calling 'sync', we just run:
# object.each { |subobj| subobj.sync() }

# to use this interface, just define an 'each' method and 'include Blink::Interface'
module Blink
	class Interface
        # this is a bit of a hack, but it'll work for now
        attr_accessor :performoperation
        attr_writer :noop

		@@allobjects = Array.new # an array for all objects

		#---------------------------------------------------------------
		#---------------------------------------------------------------
        # these objects are used for mapping type names (e.g., 'file')
        # to actual object classes; because Interface.inherited is
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
        def Interface.newtype(type)
            @@typeary.push(type)
            if @@typehash.has_key?(type.name)
                Blink.notice("Redefining object type %s" % type.name)
            end
            @@typehash[type.name] = type
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def Interface.type(type)
            @@typehash[type]
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # this is meant to be run multiple times, e.g., when a new
        # type is defined at run-time
        def Interface.buildtypehash
            unless @@typeary.length == @@typehash.length
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
        end
		#---------------------------------------------------------------
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# retrieve a named object
		def Interface.[](name)
			if @objects.has_key?(name)
				return @objects[name]
			else
				raise "Object '#{name}' does not exist"
			end
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		def Interface.[]=(name,object)
            newobj = nil
            if object.is_a?(Blink::Interface)
                newobj = object
            else
                raise "must pass a Blink::Interface object"
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
		def Interface.push(object)
			@@allobjects.push object
			#Blink.debug("adding %s of type %s to master list" %
            #    [object.name,object.class])
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
		# some simple stuff to make it easier to get a name from everyone
		def Interface.namevar
			return @namevar
		end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def Interface.has_key?(name)
            return @objects.has_key?(name)
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # this should make it so our subclasses don't have to worry about
        # defining these class instance variables
		def Interface.inherited(sub)
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
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # this is used for mapping object types (e.g., Blink::Types::File)
        # to names (e.g., "file")
        def Interface.name
            return @name
        end
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
        # return the full path to us, for logging and rollback
        # some classes (e.g., FileTypeRecords) will have to override this
        def fqpath
            return self.class, self.name
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
                # do all subclasses of Interface contain all of their
                # content in contained objects?
                Blink::Modification.new(contained)
            }
        end
		#---------------------------------------------------------------
	end
end
