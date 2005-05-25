#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'blink/type'

module Blink
    class Type
class TypeGenerator < Blink::Type
    include Enumerable

    @namevar = :name
    @name = :typegen
    @abstract = true

    #---------------------------------------------------------------
    def TypeGenerator.[](name)
        return @subclasses[name]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.inherited(subclass)
        #subclass.initvars
        super(subclass)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # we don't need to 'super' here because type.rb already runs initvars
    # in Type#inherited
    def TypeGenerator.initvars
        @subclasses = Hash.new(nil)
        super
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.name
        return @name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.name=(name)
        @name = name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.namevar
        return @namevar || :name
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.namevar=(namevar)
        Blink.debug "Setting namevar for %s to %s" % [self,namevar]
        unless namevar.is_a? Symbol
            namevar = namevar.intern
        end
        @namevar = namevar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def TypeGenerator.newtype(arghash)
        unless defined? @parameters
            raise "Type %s is set up incorrectly" % self
        end

        arghash.each { |key,value|
            if key.class != Symbol
                # convert to a symbol
                arghash[key.intern] = value
                arghash.delete key
                key = key.intern
            end
            unless @parameters.include?(key)
                raise "Invalid argument %s on class %s" %
                    [key,self]
            end

        }

        # turn off automatically checking all arguments
        #@parameters.each { |option|
        #    unless arghash.include?(option)
        #        p arghash
        #        raise "Must pass %s to class %s" %
        #            [option,self]
        #    end
        #}

        if @subclasses.include?(arghash[:name])
            raise "File type %s already exists" % arghash[:name]
        end

        klassname = arghash[:name].capitalize

        # create the file type
        Blink::Type.module_eval "
            class %s < %s
            end" % [klassname,self]
        klass = eval(klassname)
        klass.name = arghash[:name]

        @subclasses[arghash[:name]] = klass

        arghash.each { |option,value|
            method = option.id2name + "="
            if klass.respond_to?(method)
                #Blink.debug "Setting %s on %s to '%s'" % [option,klass,arghash[option]]
                klass.send(method,arghash[option])
            else
                Blink.debug "%s does not respond to %s" % [klass,method]
            end
        }

        # i couldn't get the method definition stuff to work
        # oh well
        # probably wouldn't want it in the end anyway
        #@parameters.each { |option|
        #    writer = option.id2name + "="
        #    readproc = proc { eval("@" + option.id2name) }
        #    klass.send(:define_method,option,readproc)
        #    writeproc = proc { |value| module_eval("@" + option.id2name) = value }
        #    klass.send(:define_method,writer,writeproc)
        #    klass.send(writer,hash[option])
        #}

        #Blink::Type.inherited(klass)
        Blink::Type.buildtypehash
        return klass
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
end
end
