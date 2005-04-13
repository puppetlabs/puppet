#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'blink'
require 'blink/function'

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
                list.each { |object|
                    # create a Blink object from the list...
                }
            end
        end
    end
    #---------------------------------------------------------------
end
