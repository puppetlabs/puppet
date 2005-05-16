#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'blink/type'
require 'blink/type/typegen'

class Blink::Type::FileType < Blink::Type::TypeGenerator
    attr_accessor :childtype

    @options = [:name, :linesplit, :escapednewlines]
    @abstract = true
    @metaclass = true

    @name = :filetype

    @modsystem = true

    #---------------------------------------------------------------
    def FileType.newtype(hash)
        unless hash.include?(:linesplit)
            hash[:linesplit] = "\n"
        end
        klass = super(hash)

        klass.escapednewlines = true

        #klass.childtype = Blink::Type::FileRecord.newtype(
        #    :name => hash[:name] + "_record",
        #    :splitchar => hash[:recordsplit],
        #    :fields => hash[:fields],
        #    :namevar => hash[:namevar]
        #)
        #klass.addrecord(
        #    :name => hash[:name] + "_record",
        #    :splitchar => hash[:recordsplit],
        #    :fields => hash[:fields],
        #    :namevar => hash[:namevar]
        #)

        return klass
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # currently not used
    def FileType.addrecord(hash)
        unless defined? @records
            @records = {}
        end
        hash[:filetype] = self
        
        # default to the naming field being the first field provided
        unless hash.include?(:namevar)
            hash[:namevar] = hash[:fields][0]
        end

        recordtype = Blink::Type::FileRecord.newtype(hash)
        @records[recordtype.name] = recordtype
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.records
        return @records
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.escapednewlines=(value)
        @escnlines = value
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.escapednewlines
        if ! defined? @escnlines or @escnlines.nil?
            return false
        else
            return @escnlines
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.childtype
        unless defined? @childtype
            @childtype = nil
        end
        return @childtype
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.childtype=(childtype)
        @childtype = childtype
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.regex
        return @regex
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.linesplit=(linesplit)
        @regex = %r{#{linesplit}}
        @linesplit = linesplit
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def FileType.linesplit
        return @linesplit
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def [](name)
        return @childhash[name]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def []=(name,value)
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # we don't really have a 'less-than/greater-than' sense here
    # so i'm sticking with 'equals' until those make sense
    def ==(other)
        unless self.children.length == other.children.length
            Blink.debug("file has %s records instead of %s" %
                [self.children.length, other.children.length])
            return self.children.length == other.children.length
        end
        equal = true
        self.zip(other.children) { |schild,ochild|
            unless schild == ochild
                Blink.debug("%s has changed in %s" %
                    [schild.name,self.name])
                equal = false
                break
            end
        }

        return equal
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # create a new record with a block
    def add(type,&block)
        obj = self.class.records[type].new(self,&block)
        Blink.debug("adding %s" % obj.name)
        @childary.push(obj)
        @childhash[obj.name] = obj

        return obj
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def children
        return @childary
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # remove a record
    def delete(name)
        if @childhash.has_key?(name)
            child = @childhash[name]

            @childhash.delete(child)
            @childary.delete(child)
        else
            raise "No such entry %s" % name
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def each
        @childary.each { |child|
            yield child
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # create a new file
    def initialize(file)
        @file = file

        @childary = []
        @childhash = {}
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this is where we're pretty different from other objects
    # we can choose to either reparse the existing file and compare
    # the objects, or we can write our file out and do an
    # text comparison
    def insync?
        tmp = self.class.new(@file)
        tmp.retrieve

        return self == tmp
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def name
        return @file
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # read the whole file in and turn it into each of the appropriate
    # objects
    def retrieve
        str = ""
        ::File.open(@file) { |fname|
            fname.each { |line|
                str += line
            }
        }

        if self.class.escapednewlines
            endreg = %r{\\\n\s*}
            str.gsub!(endreg,'')
        end
        @childary = str.split(self.class.regex).collect { |line|
            childobj = nil
            self.class.records.each { |name,recordtype|
                if childobj = recordtype.match(self,line)
                    break
                end
            }
            if childobj.nil?
                Blink.warning("%s: could not match %s" % [self.name,line])
                #Blink.warning("could not match %s" % line)
                next
            end

            begin
                Blink.debug("got child: %s(%s)" % [childobj.class,childobj.to_s])
            rescue NoMethodError
                Blink.warning "Failed: %s" % childobj
            end
            childobj
        }.reject { |child|
            child.nil?
        }

        @childary.each { |child|
            begin
                @childhash[child.name] = child
            rescue NoMethodError => detail
                p child
                p child.class
                puts detail
                exit
            end
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def sync
        #unless self.insync?
            self.write
        #end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def to_s
        return @childary.collect { |child|
            child.to_s
        }.join(self.class.linesplit) + self.class.linesplit
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def write
        ::File.open(@file, "w") { |file|
            file.write(self.to_s)
        }
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
