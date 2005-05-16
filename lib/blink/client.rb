#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'blink'
require 'blink/function'
require 'blink/type'
require 'blink/transaction'
require 'blink/transportable'

module Blink
    class ClientError < RuntimeError; end
    #---------------------------------------------------------------
    class Client
        attr_accessor :objects

        class Local
            def callfunc(name,args)
                if function = Blink::Function[name]
                    #Blink.debug("calling function %s" % function)
                    value = function.call(args)
                    #Blink.debug("from %s got %s" % [name,value])
                    return value
                else
                    raise "Function '%s' not found" % name
                end
            end

            # this method is how the client receives the tree of Transportable
            # objects
            # for now, just descend into the tree and perform and necessary
            # manipulations
            def objects=(tree)
                container = tree.to_type

                # for now we just evaluate the top-level container, but eventually
                # there will be schedules and such associated with each object,
                # and probably with the container itself
                transaction = container.evaluate
                #transaction = Blink::Transaction.new(objects)
                transaction.evaluate
            end
        end
    end
    #---------------------------------------------------------------
end
