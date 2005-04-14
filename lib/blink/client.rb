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
            def callfunc(name,*args)
                if function = Blink::Function[name]
                    return function.call(*args)
                else
                    return nil
                end
            end

            def objects=(list)
                Blink::Types.buildtypehash # refresh the list of available types

                objects = []
                list.each { |object|
                    # create a Blink object from the list...
                    if type = Blink::Types.type(object.type)
                        namevar = type.namevar
                        Blink.notice("%s namevar is %s" % [type.name,namevar])
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
