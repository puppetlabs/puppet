#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'blink/type'

module Blink
    class TypeGenerator < Blink::Type
        include Enumerable

        @namevar = :notused
        @name = :typegen

        attr_accessor :childtype

        @@subclasses = Hash.new(nil)

		#---------------------------------------------------------------
        def TypeGenerator.[](name)
            return @@classes[name]
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def TypeGenerator.childtype=(childtype)
            @childtype = childtype
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def TypeGenerator.childtype
            return @childtype
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
            return :notused
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def TypeGenerator.newtype(arghash)
            unless defined? @options
                raise "Type %s is set up incorrectly" % self
            end

            arghash.each { |key,value|
                unless options.include?(key)
                    raise "Invalid argument %s on class %s" %
                        [key,self]
                end
            }
            options.each { |option|
                unless arghash.include?(option)
                    raise "Must pass %s to class %s" %
                        [option,self.class.to_s]
                end
            }

            if @@subclasses.include?(arghash[:name])
                raise "File type %s already exists" % arghash[:name]
            end

            klassname = arghash[:name].capitalize

            # create the file type
            module_eval "
                class %s < TypeGenerator
                end" % klassname
            klass = eval(klassname)
            klass.name = arghash[:name]

            Blink.debug("adding class %s as a subclass of %s" % [arghash[:name],self])
            @@subclasses[arghash[:name]] = klass

            return klass
        end
		#---------------------------------------------------------------
    end
    #---------------------------------------------------------------
end
