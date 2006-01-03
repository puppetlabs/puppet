
# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'puppet/type'
require 'puppet/type/typegen'

class Puppet::Type::FileRecord < Puppet::Type::TypeGenerator
    class << self
        # The name of the record type.  Probably superfluous.
        attr_accessor :name

        # What character we split on to convert from a line into a set of fields.
        # This can be either a string or a regex and defaults to /\s+/
        attr_accessor :fieldsep

        # The fields in this record type.
        attr_accessor :fields

        # Which of the fields counts as the name of the record.  Defaults to the
        # first field.
        attr_accessor :namevar

        # Which filetype this record type is associated with.  Essentially useless.
        attr_accessor :filetype

        # An optional regex to use to match fields.  This can be used instead
        # of splitting based on a character and must use match sets to return
        # the fields.  If this is not set, then a regex is created from the
        # fieldsep.  If your regex is complicated enough that you have nested
        # parentheses, then just set your fields up so that the non-field matches
        # are nil.
        attr_writer :regex

        # The character(s) to use to join the records back together.  If this is
        # not set, then 'fieldsep' will be used instead, which means that this
        # *must* be set if 'fieldsep' is a regex or if the record regex is set.
        attr_accessor :fieldjoin

        # Some records (like cron jobs) don't have a name field, so we have to
        # store the name in the previous comment.  Dern.  If we are doing this,
        # it is assumed that some objects won't yet have names, so we'll generate
        # names for those cases.
        attr_accessor :extname
    end

    def FileRecord.newtype(hash)
        # Provide some defaults.
        newklass = Class.new(self)

        # If they've passed in values, then set them appropriately.
        unless hash.empty?
            hash.each { |param, val|
                meth = param.to_s + "="
                if self.respond_to? meth
                    self.send(meth, val)
                end
            }
        end

        # If they've provided a block, then yield to it
        if block_given?
            yield newklass
        end

        return newklass
    end

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

    def FileRecord.regex
        # the only time @regex is allowed to be nil is if @fieldsep is defined
        if @regex.nil?
            if @fieldsep.nil?
                raise Puppet::DevError,
                    "%s defined incorrectly -- fieldsep or regex must be specified" %
                    self
            else
                ary = []
                text = @fields.collect { |field|
                    "([^%s]*)" % @fieldsep
                }.join(@fieldsep)
                begin
                    @regex = Regexp.new(text)
                rescue RegexpError => detail
                    raise Puppet::DevError,
                        "Could not create splitregex from %s" % @fieldsep
                end
                debug("Created regexp %s" % @regex)
            end
        elsif @regex.is_a?(String)
            begin
                @regex = Regexp.new(@regex)
            rescue RegexpError => detail
                raise Puppet::DevError, "Could not create splitregex from %s" % @regex
            end
        end
        return @regex
    end

    def ==(other)
        unless self.class == other.class
            return false
        end

        unless self.name == other.name
            return false
        end
        @parameters.keys { |field|
            unless self[field] == other[field]
                debug("%s -> %s has changed" % [self.name, field])
                return false
            end
        }
        return true
    end

    def initialize(hash)
        if self.class == Puppet::Type::FileRecord
            self.class.newtype(hash)
            return
        end
        @parameters = {}
        #if block_given?
        #    yield self
        #end
        super(hash)
    end

    def match=(matchobj)
        @match = matchobj
        #puts "captures are [%s]" % [matchobj.captures]
        self.class.fields.zip(matchobj.captures) { |field,value|
            @parameters[field] = value
            #puts "%s => %s" % [field,@parameters[field]]
        }
    end

    def record=(record)
        begin
            ary = record.split(self.class.regex)
        rescue RegexpError => detail
            raise RegexpError.new(detail)
        end
        self.class.fields.each { |field|
            @parameters[field] = ary.shift
            #puts "%s => %s" % [field,@parameters[field]]
        }
    end

    def name
        if @parameters.include?(self.class.namevar)
            return @parameters[self.class.namevar]
        else
            raise "No namevar '%s' for objects of type %s" %
                [self.class.namevar,self.class.to_s]
        end
    end

    def to_s
        ary = self.class.fields.collect { |field|
            if ! @parameters.include?(field)
                raise "Object %s is missing field %s" % [self.name,field]
            else
                @parameters[field]
            end
        }.join(self.class.fieldjoin || self.class.fieldsep)
    end
end

# $Id$
