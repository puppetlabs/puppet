#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'blink'
require 'blink/function'
require 'blink/type'

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

            def objects=(list)
                objects = list.collect { |object|
                    # create a Blink object from the list...
                    #puts "yayness"
                    if type = Blink::Type.type(object.type)
                        namevar = type.namevar
                        if namevar != :name
                            object[namevar] = object[:name]
                            object.delete(:name)
                        end
                        type.new(object)
                    else
                        raise "Could not find object type %s" % object.type
                    end
                }

                # okay, we have a list of all of the objects we're supposed
                # to execute
                # here's where we collect the rollbacks and record them
                # that means that we need, at the least:
                #   - a standard mechanism for specifying that an object is no-op
                #   - a standard object that is considered a rollback object
                objects.each { |obj|
                    obj.evaluate
                }
            end
        end
    end
    #---------------------------------------------------------------
end
