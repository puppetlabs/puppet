#!/usr/local/bin/ruby -w

# $Id$

# the definition of our state tree
# the base class for both leaves and branches, and the base class for each
# of them, also

require 'blink'
require 'blink/statechange'

#---------------------------------------------------------------
class Blink::Element
    attr_accessor :noop

    #---------------------------------------------------------------
    @@interface_methods = [
        :retrieve, :insync?, :sync, :fqpath, :evaluate, :refresh
    ]

    @@interface_methods.each { |method|
        self.send(:define_method,method) {
            raise "%s has not overridden %s" % [self.class,method]
        }
    }

    class Blink::Element::Branch
        attr_accessor :children, :parent, :states

		#---------------------------------------------------------------
        # iterate across all children, and then iterate across states
        # we do children first so we're sure that all dependent objects
        # are checked first
        def each
            [@children,@states].each { |child|
                yield child
            }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # this method is responsible for collecting state changes
        # we always descend into the children before we evaluate our current
        # states
        def evaluate(transaction)
            self.each { |child| child.evaluate }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def initialize
            @childary = []
            @childhash = {}
            @states = []
            @parent = nil
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
    end

    #---------------------------------------------------------------
    class Blink::Element::Leaf
        attr_accessor :is, :should, :parent

        #---------------------------------------------------------------
        # this assumes the controlling process will actually execute the change
        # which will demonstrably not work with states that are part of a larger
        # whole, like FileRecordStates
        def evaluate(transaction)
            self.retrieve
            transaction.change(Blink::StateChange.new(state)) unless self.insync?
        end
        #---------------------------------------------------------------

		#---------------------------------------------------------------
        def initialize
            @is = nil
            @should = nil
            @parent = nil
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def refresh(transaction)
            self.retrieve

            # we definitely need some way to batch these refreshes, so a
            # given object doesn't get refreshed multiple times in a single
            # run
            @parent.refresh
        end
		#---------------------------------------------------------------
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
