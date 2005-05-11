#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'blink'
require 'blink/function'
require 'blink/type'
require 'blink/transaction'

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
                objects = []
                list.collect { |object|
                    Blink.verbose "object %s" % [object]
                    # create a Blink object from the list...
                    #puts "yayness"
                    if type = Blink::Type.type(object.type)
                        namevar = type.namevar
                        puts object.inspect
                        if namevar != :name
                            object[namevar] = object[:name]
                            object.delete(:name)
                        end
                        puts object.inspect
                        begin
                            puts object.inspect
                            typeobj = type.new(object)
                            Blink.verbose "object %s is %s" % [object,typeobj]
                            objects.push typeobj
                        rescue => detail
                            puts "Failed to create object: %s" % detail 
                            puts object.class
                            puts object.inspect
                            exit
                        end
                    else
                        raise "Could not find object type %s" % object.type
                    end
                }
                Blink.verbose "object length is %s" % objects.length

                # okay, we have a list of all of the objects we're supposed
                # to execute
                # here's where we collect the rollbacks and record them
                # that means that we need, at the least:
                #   - a standard mechanism for specifying that an object is no-op
                #   - a standard object that is considered a rollback object
                #objects.each { |obj|
                #    obj.evaluate
                #}

                transaction = Blink::Transaction.new(objects)
                transaction.run
            end
        end
    end
    #---------------------------------------------------------------
end
