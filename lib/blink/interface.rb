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
        # each subclass of Blink::Interface must create a class-local @objects
        # variable
        @objects = Hash.new # this one won't be used, since this class is abstract

        # this is a bit of a hack, but it'll work for now
        attr_accessor :performoperation

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
		# this is special, because it can be equivalent to running new
		# this allows cool syntax like Blink::File["/etc/inetd.conf"] = ...
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
        def Interface.has_key?(name)
            return @objects.has_key?(name)
        end
		#---------------------------------------------------------------
	end
end
