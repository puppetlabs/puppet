#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'blink/type'
require 'blink/type/typegen'

#---------------------------------------------------------------
class Blink::Type::FileRecord < Blink::Type::TypeGenerator
    attr_accessor :fields, :namevar, :splitchar, :object

    @parameters = [:name, :splitchar, :fields, :namevar, :filetype, :regex, :joinchar]
    @abstract = true
    @metaclass = true

    @namevar = :name
    @name = :filerecord

    #---------------------------------------------------------------
    def FileRecord.newtype(hash)
        #shortname = hash[:name]
        #hash[:name] = hash[:filetype].name.capitalize + hash[:name].capitalize
        klass = super(hash)
        #klass.name = shortname
        klass.parameters = hash[:fields]
        #klass.namevar = hash[:namevar]
        klass.filetype = hash[:filetype]
        hash.delete(:fields)
        hash.delete(:namevar)
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
        if filetype.is_a?(String)
            @filetype = Blink::Type::FileType[filetype]
        elsif filetype.is_a?(Blink::Type::FileType)
            @filetype = filetype
        else
            raise "Cannot use objects of type %s as filetypes" % filetype 
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.joinchar=(char)
        @joinchar = char
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.joinchar
        unless defined? @joinchar
            @joinchar = nil
        end
        @joinchar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.match(object,line)
        matchobj = nil
        begin
            matchobj = self.regex.match(line)
        rescue RegexpError => detail
            raise
        end

        if matchobj.nil?
            return nil
        else
            child = self.new(object)
            child.match = matchobj
            return child
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.regex=(regex)
        @regex = regex
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.regex
        # the only time @regex is allowed to be nil is if @splitchar is defined
        if @regex.nil?
            if @splitchar.nil?
                raise "%s defined incorrectly -- splitchar or regex must be specified" %
                    self
            else
                ary = []
                text = @fields.collect { |field|
                    "([^%s]*)" % @splitchar
                }.join(@splitchar)
                begin
                    @regex = Regexp.new(text)
                rescue RegexpError => detail
                    raise "Could not create splitregex from %s" % @splitchar
                end
                Blink.debug("Created regexp %s" % @regex)
            end
        elsif @regex.is_a?(String)
            begin
                @regex = Regexp.new(@regex)
            rescue RegexpError => detail
                raise "Could not create splitregex from %s" % @regex
            end
        end
        return @regex
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.splitchar=(char)
        @splitchar = char
        #@regex = %r{#{char}}
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileRecord.splitchar
        return @splitchar
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #def [](field)
    #    @parameters[field]
    #end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    #def []=(field,value)
    #    @parameters[field] = value
    #end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def ==(other)
        unless self.class == other.class
            return false
        end

        unless self.name == other.name
            return false
        end
        @parameters.keys { |field|
            unless self[field] == other[field]
                Blink.debug("%s -> %s has changed" % [self.name, field])
                return false
            end
        }
        return true
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def initialize(hash)
        if self.class == Blink::Type::FileRecord
            self.class.newtype(hash)
            return
        end
        @parameters = {}
        #if block_given?
        #    yield self
        #end
        super(hash)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def match=(matchobj)
        @match = matchobj
        #puts "captures are [%s]" % [matchobj.captures]
        self.class.fields.zip(matchobj.captures) { |field,value|
            @parameters[field] = value
            #puts "%s => %s" % [field,@parameters[field]]
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def record=(record)
        begin
            ary = record.split(self.class.regex)
        rescue RegexpError=> detail
            raise RegexpError.new(detail)
        end
        self.class.fields.each { |field|
            @parameters[field] = ary.shift
            #puts "%s => %s" % [field,@parameters[field]]
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def name
        if @parameters.include?(self.class.namevar)
            return @parameters[self.class.namevar]
        else
            raise "No namevar '%s' for objects of type %s" %
                [self.class.namevar,self.class.to_s]
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        ary = self.class.fields.collect { |field|
            if ! @parameters.include?(field)
                raise "Object %s is missing field %s" % [self.name,field]
            else
                @parameters[field]
            end
        }.join(self.class.joinchar || self.class.splitchar)
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
