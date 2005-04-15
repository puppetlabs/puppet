#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'blink'
require 'blink/function'
require 'blink/types'

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
                Blink::Types.buildtypehash # refresh the list of available types

                objects = []
                list.each { |object|
                    # create a Blink object from the list...
                    if type = Blink::Types.type(object.type)
                        namevar = type.namevar
                        if namevar != :name
                            object[namevar] = object[:name]
                            object.delete(:name)
                        end
                        obj = type.new(object)
                    else
                        raise "Could not find object type %s" % object.type
                    end
                }
            end
        end
    end
    #---------------------------------------------------------------
end
