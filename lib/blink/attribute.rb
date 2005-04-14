#!/usr/local/bin/ruby -w

# $Id$

module Blink
	# this is a virtual base class for attributes
    # attributes are self-contained building blocks for objects

    # Attributes can currently only be used for comparing a virtual "should" value
    # against the real state of the system.  For instance, you could verify that
    # a file's owner is what you want, but you could not create two file objects
    # and use these methods to verify that they have the same owner
	class Attribute
        include Comparable

		attr_accessor :value
		attr_accessor :should
		attr_accessor :object

		#-----------------------------------
        # every attribute class must tell us what it's name will be (as a symbol)
        # this determines how we will refer to the attribute during usage
        # e.g., the Owner attribute for Files might say its name is :owner;
        # this means that we can say "file[:owner] = 'yayness'"
        def Attribute.name
            return @name
        end
		#-----------------------------------

		#-----------------------------------
        # we aren't actually comparing the attributes themselves, we're only
        # comparing the "should" value with the "real" value
        def insync?
            Blink.debug "%s value is %s, should be %s" % [self,self.value,self.should]
            self.value == self.should
        end
		#-----------------------------------

		#-----------------------------------
        def initialize(value)
            @should = value
        end
		#-----------------------------------

		#-----------------------------------
        # DISABLED: we aren't comparing attributes, just attribute values
		# are we in sync?
        # this could be a comparison between two attributes on two objects,
        # or a comparison between an object and the live system -- we'll
        # let the object decide that, rather than us
		#def <=>(other)
        #    if (self.value.respond_to?(:<=>))
        #        return self.value <=> other
        #    else
        #        fail TypeError.new("class #{self.value.class} does not respond to <=>")
        #    end
		#end
		#-----------------------------------

		#-----------------------------------
        # each attribute class must define the name() method
        def name
            return self.class.name
        end
		#-----------------------------------

		#-----------------------------------
		# retrieve the current state from the running system
		def retrieve
			raise "'retrieve' method was not overridden by %s" % self.class
		end
		#-----------------------------------

		#-----------------------------------
		def to_s
			return @object.name.to_s + " -> " + self.name.to_s
		end
		#-----------------------------------

		#-----------------------------------
        # this class is for attributes that don't reflect on disk,
        # like 'path' on files and 'name' on processes
        # these are basically organizational attributes, not functional ones
        #
        # we provide stub methods, so that from the outside it looks like
        # other attributes
        #
        # see objects.rb for how this is used
        class Symbol
            attr_reader :value
            attr_reader :should

            def initialize(symbol)
                @symbol = symbol
            end

            def name
                return @symbol.id2name
            end

            def retrieve
                true
            end

            def insync?
                true
            end

            def should=(value)
                @value = value
                @should = value
            end

            def sync
                true
            end

            def value=(value)
                @value = value
                @should = value
            end
        end
	end

    # this class is supposed to be used to solve cases like file modes,
    # where one command (stat) retrieves enough data to cover many attributes
    # (e.g., setuid, setgid, world-read, etc.)
    class MetaAttribute
        include Comparable
        attr_accessor :parent
        attr_accessor :value

        def <=>(other)
			raise "'<=>' method was not overridden by %s" % self.class
        end
    end
end
