#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'blink/type'
require 'blink/type/typegen'

#---------------------------------------------------------------
class Blink::Type::FileRecord < Blink::Type::TypeGenerator
    attr_accessor :fields, :namevar, :splitchar, :object

    @options = [:name, :splitchar, :fields, :namevar, :filetype]
    @abstract = true

    @name = :filerecord

    #---------------------------------------------------------------
    def FileRecord.newtype(hash)
        shortname = hash[:name]
        hash[:name] = hash[:filetype].name.capitalize + hash[:name].capitalize
        klass = super(hash)
        klass.name = shortname
        return klass
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.fields=(ary)
        @fields = ary
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.fields
        return @fields
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.filetype
        @filetype
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.filetype=(filetype)
        @filetype = filetype
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.match(object,line)
        if @regex.match(line)
            child = self.new(object)
            child.record = line
            return child
        else
            return nil
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.namevar=(field)
        @namevar = field
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.namevar
        return @namevar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.regex
        return @regex
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.splitchar=(char)
        @splitchar = char
        @regex = %r{#{char}}
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.splitchar
        return @splitchar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def [](field)
        @fields[field]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def []=(field,value)
        @fields[field] = value
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def ==(other)
        unless self.class == other.class
            return false
        end

        unless self.name == other.name
            return false
        end
        @fields.keys { |field|
            unless self[field] == other[field]
                Blink.debug("%s -> %s has changed" % [self.name, field])
                return false
            end
        }
        return true
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def initialize(object)
        @object = object
        @fields = {}
        if block_given?
            yield self
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def record=(record)
        ary = record.split(self.class.regex)
        self.class.fields.each { |field|
            @fields[field] = ary.shift
            #puts "%s => %s" % [field,@fields[field]]
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def name
        if @fields.include?(self.class.namevar)
            return @fields[self.class.namevar]
        else
            raise "No namevar for objects of type %s" % self.class.to_s
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        ary = self.class.fields.collect { |field|
            if ! @fields.include?(field)
                raise "Object %s is missing field %s" % [self.name,field]
            else
                @fields[field]
            end
        }.join(self.class.splitchar)
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
