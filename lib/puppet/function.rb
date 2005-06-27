#!/usr/local/bin/ruby -w

# $Id$

require 'puppet'
require 'puppet/fact'

module Puppet
    class Function
        @@functions = Hash.new(nil)

        #---------------------------------------------------------------
        def Function.[](name)
            return @@functions[name]
        end
        #---------------------------------------------------------------

        #---------------------------------------------------------------
        def call(args)
            @code.call(args)
        end
        #---------------------------------------------------------------

        #---------------------------------------------------------------
        # we want a 'proc' item instead of a block, so that we can return
        # from it
        def initialize(name,code)
            @name = name
            @code = code

            @@functions[name] = self
        end
        #---------------------------------------------------------------
    end

    Function.new("fact", proc { |fact|
        require 'puppet/fact'

        value = Fact[fact]
        Puppet.debug("retrieved %s as %s" % [fact,value])
        value
    })

    Function.new("addfact", proc { |args|
        require 'puppet/fact'
        #Puppet.debug("running addfact")

        hash = nil
        if args.is_a?(Array)
            hash = Hash[*args]
        end
        name = nil
        if hash.has_key?("name")
            name = hash["name"]
            hash.delete("name")
        elsif hash.has_key?(:name)
            name = hash[:name]
            hash.delete(:name)
        else
            raise "Functions must have names"
        end
        #Puppet.debug("adding fact %s" % name)
        newfact = Fact.add(name) { |fact|
            hash.each { |key,value|
                method = key + "="
                fact.send(method,value)
            }
        }

        #Puppet.debug("got fact %s" % newfact)
    })
end
