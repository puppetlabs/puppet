#!/usr/local/bin/ruby -w

# $Id$

# an interface for registering and retrieving facts
# this is an abstract interface, and should just be used to interact
# with another library

# currently a very thin veneer on 'facter'

require 'facter'
require 'blink'
require 'blink/type'

module Blink
	class Fact
        def Fact.[](name)
            fact = Facter[name]
            if fact.value.nil?
                raise "Could not retrieve fact %s" % name
            end
            Blink.debug("fact: got %s from %s for %s" % [fact.value,fact,name])
            return fact.value
        end

        # just pass the block to 'add'
        # the block has to do things like set the interpreter,
        # the code (which can be a ruby block), and maybe the
        # os and osrelease
        def Fact.add(name,&block)
            Facter[name].add(&block)
        end

        def Fact.name
            return :fact
        end

        def Fact.namevar
            return :name
        end

        #Blink::Type.newtype(self)

        # we're adding a new resolution mechanism here; this is just how
        # types work
        # we don't have any real interest in the returned object
        def initialize(hash)
            name = hash[:name]
            hash.delete(:name)
            Fact.add(name) { |fact|
                method = nil
                hash.each { |key,value|
                    if key.is_a?(String)
                        method = key + "="
                    elsif key.is_a?(Symbol)
                        method = key.id2name + "="
                    else
                        raise "Key must be either string or symbol"
                    end
                    fact.send(method,value)
                }
            }
        end
    end
end
