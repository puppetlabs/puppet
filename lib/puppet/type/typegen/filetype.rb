# parse and write configuration files using objects with minimal parsing abilities

require 'puppet/type'
require 'puppet/type/typegen'

class Puppet.type(:filetype) < Puppet::Type::TypeGenerator
    @parameters = [:name, :recordsep, :escapednewlines]

    @namevar = :name
    @name = :filetype

    @modsystem = true

    class << self
        # Which field in the record functions as the name of the record.
        attr_accessor :namevar

        # Does this filetype support escaped newlines?  Defaults to false.
        attr_accessor :escapednewlines

        # What do comments in this filetype look like? Defaults to /^#|^\s/
        attr_accessor :comment

        # What is the record separator?  Defaults to "\n".
        attr_accessor :recordsep

        # How do we separate records?  Normally we just turn the recordsep
        # into a regex, but you can override that, or just not use the recordsep.
        attr_writer :regex
    end

    # Add a new record to our filetype.  This should never be called on the FileType
    # class itself, only on its subclasses.
    def FileType.addrecord(hash = {})
        if self == Puppet.type(:filerecord)
            raise Puppet::DevError, "Cannot add records to the FileType base class"
        end

        newrecord = Puppet.type(:filerecord).newtype(hash)
        newrecord.filetype = self

        if block_given?
            yield newrecord
        end

        unless defined? @records
            @records = []
        end

        @records << newrecord
    end

    # Remove all defined filetypes.  Mostly used for testing.
    def self.clear
        if defined? @subclasses
            @subclasses.each { |sub|
                sub.clear
            }
            @subclasses.clear
        end

        if defined? @records
            @records.clear
        end
    end

    # Yield each record in turn, so we can iterate over each of them.
    def self.eachrecord
        @records.each { |record|
            yield record
        }
    end

    # Create a new file type.  You would generally provide an initialization block
    # for this method:
    #
    #   FileType.newtype do |type|
    #       @name = "cron"
    #       type.addrecord do |record|
    #           @name = "cronjob"
    #           @splitchar = "\t"
    #           @fields = [:minute, :hour, :monthday, :month, :weekday, :command]
    #       end
    #   end
    #
    # You don't actually have to provide anything at initialization time, but your
    # filetype won't be much use if you don't at least provide it with some record
    # types.  You will generally only have one record type, since comments are
    # handled transparently, although you might have to define what looks like a
    # comment (the default is anything starting with a '#' or any whitespace).
    def FileType.newtype(hash = {})
        unless defined? @subclasses
            @subclasses = Hash.new
        end

        # Provide some defaults.
        newklass = Class.new(self) do
            @escapednewlines = true
            @namevar = :name
            @comment = /^#|^\s/
            @recordsep = "\n"
        end

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

        @subclasses << newklass
        return newklass
    end

    # Return the defined regex or the recordsep converted to one.
    def FileType.regex
        unless defined? @regex
            @regex = %r{#{recordsep}}
        end
        return @regex
    end

    # we don't really have a 'less-than/greater-than' sense here
    # so i'm sticking with 'equals' until those make sense
    def ==(other)
        unless self.children.length == other.children.length
            Puppet.debug("file has %s records instead of %s" %
                [self.children.length, other.children.length])
            return self.children.length == other.children.length
        end
        equal = true
        self.zip(other.children) { |schild,ochild|
            unless schild == ochild
                Puppet.debug("%s has changed in %s" %
                    [schild.name,self.name])
                equal = false
                break
            end
        }

        return equal
    end

    # create a new record with a block
    def add(type,&block)
        obj = self.class.records[type].new(self,&block)
        debug("adding %s" % obj.name)
        @childary.push(obj)
        @childhash[obj.name] = obj

        return obj
    end

    def children
        return @childary
    end

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

    def each
        @childary.each { |child|
            yield child
        }
    end

    # create a new file
    def initialize(hash)
        # if we are the FileType object itself, we create a new type
        # otherwise, we create an instance of an existing type
        # yes, this should be more straightforward
        if self.class == Puppet.type(:filetype)
            self.class.newtype(hash)
            return
        end
        debug "Creating new '%s' file with path '%s' and name '%s'" %
            [self.class.name,hash["path"],hash[:name]]
        debug hash.inspect
        @file = hash["path"]

        @childary = []
        @childhash = {}
        super
    end

    # this is where we're pretty different from other objects
    # we can choose to either reparse the existing file and compare
    # the objects, or we can write our file out and do an
    # text comparison
    def insync?
        tmp = self.class.new(@file)
        tmp.retrieve

        return self == tmp
    end

    #def name
    #    return @file
    #end

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
                warning("%s: could not match %s" % [self.name,line])
                #warning("could not match %s" % line)
                next
            end

            begin
                debug("got child: %s(%s)" % [childobj.class,childobj.to_s])
            rescue NoMethodError
                warning "Failed: %s" % childobj
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

    def sync
        #unless self.insync?
            self.write
        #end
    end

    def to_s
        return @childary.collect { |child|
            child.to_s
        }.join(self.class.recordsep) + self.class.recordsep
    end

    def write
        ::File.open(@file, "w") { |file|
            file.write(self.to_s)
        }
    end
end

# $Id$
