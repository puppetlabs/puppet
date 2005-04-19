#!/usr/local/bin/ruby -w

# $Id$

module Blink
	# this is a virtual base class for states
    # states are self-contained building blocks for objects

    # States can currently only be used for comparing a virtual "should" value
    # against the real state of the system.  For instance, you could verify that
    # a file's owner is what you want, but you could not create two file objects
    # and use these methods to verify that they have the same owner
	class State
        include Comparable

		attr_accessor :is, :should, :object

		#-----------------------------------
        # every state class must tell us what it's name will be (as a symbol)
        # this determines how we will refer to the state during usage
        # e.g., the Owner state for Files might say its name is :owner;
        # this means that we can say "file[:owner] = 'yayness'"
        def State.name
            return @name
        end
		#-----------------------------------

		#-----------------------------------
        # return the full path to us, for logging and rollback
        def fqpath
            return @object.fqpath, self.name
        end
		#-----------------------------------

		#-----------------------------------
        # we aren't actually comparing the states themselves, we're only
        # comparing the "should" value with the "is" value
        def insync?
            Blink.debug "%s value is %s, should be %s" % [self,self.is,self.should]
            self.is == self.should
        end
		#-----------------------------------

		#-----------------------------------
        def initialize(value)
            @should = value
        end
		#-----------------------------------

		#-----------------------------------
        # DISABLED: we aren't comparing states, just state values
		# are we in sync?
        # this could be a comparison between two states on two objects,
        # or a comparison between an object and the live system -- we'll
        # let the object decide that, rather than us
		#def <=>(other)
        #    if (self.is.respond_to?(:<=>))
        #        return self.is <=> other
        #    else
        #        fail TypeError.new("class #{self.is.class} does not respond to <=>")
        #    end
		#end
		#-----------------------------------

		#-----------------------------------
        # each state class must define the name() method
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
        # this class is for states that don't reflect on disk,
        # like 'path' on files and 'name' on processes
        # these are basically organizational states, not functional ones
        #
        # we provide stub methods, so that from the outside it looks like
        # other states
        #
        # see objects.rb for how this is used
        class Symbol
            attr_reader :is, :should

            def fqpath
                return "Symbol"
            end

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
                @is = value
                @should = value
            end

            def sync
                true
            end

            def is=(value)
                @is = value
                @should = value
            end

            def to_s
                return @is
            end
        end
	end

    # this class is supposed to be used to solve cases like file modes,
    # where one command (stat) retrieves enough data to cover many states
    # (e.g., setuid, setgid, world-read, etc.)
    class MetaState
        include Comparable
        attr_accessor :parent
        attr_accessor :is

        def <=>(other)
			raise "'<=>' method was not overridden by %s" % self.class
        end
    end
end
