#!/usr/local/bin/ruby -w

# $Id$

# parse and write configuration files using objects with minimal parsing abilities

require 'etc'
require 'blink/interface'

module Blink
    class OParse < Blink::Interface
        include Enumerable

        attr_accessor :file, :splitchar, :childtype

        @@classes = Hash.new(nil)

        def OParse.[](name)
            return @@classes[name]
        end

        def OParse.childtype=(childtype)
            @childtype = childtype
        end

        def OParse.childtype
            return @childtype
        end

        def OParse.name=(name)
            @name = name
        end

        def OParse.regex
            return @regex
        end

        def OParse.splitchar=(splitchar)
            @regex = %r{#{splitchar}}
            @splitchar = splitchar
        end

        def OParse.splitchar
            return @splitchar
        end

        def OParse.newtype(arghash)
            options = [:name, :linesplit, :recordsplit, :fields, :namevar]

            #arghash = Hash[*args]

            unless arghash.include?(:linesplit)
                arghash[:linesplit] = "\n"
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

            if @@classes.include?(arghash[:name])
                raise "File type %s already exists" % arghash[:name]
            end

            klassname = arghash[:name].capitalize

            # create the file type
            module_eval "
                class %s < OParse
                end" % klassname
            klass = eval(klassname)

            # now create the record type
            klass.childtype = Blink::OLine.newtype(
                :name => arghash[:name],
                :splitchar => arghash[:recordsplit],
                :fields => arghash[:fields],
                :namevar => arghash[:namevar]
            )
            klass.splitchar = arghash[:linesplit]
            klass.name = arghash[:name]

            Blink.debug("adding class %s" % arghash[:name])
            @@classes[arghash[:name]] = klass

            return klass
        end

        def [](name)
            return @childhash[name]
        end

        def []=(name,value)
        end

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

        def add(&block)
            obj = self.class.childtype.new(&block)
            Blink.debug("adding %s" % obj.name)
            @childary.push(obj)
            @childhash[obj.name] = obj

            return obj
        end

        def children
            return @childary
        end

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

        def initialize(file)
            @file = file

            @childary = []
            @childhash = {}
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

        def retrieve
            str = ""
            File.open(@file) { |fname|
                fname.each { |line|
                    str += line
                }
            }

            @childary = str.split(self.class.regex).collect { |record|
                child = self.class.childtype.new
                child.record = record
                #puts "adding child %s" % child.name
                child
            }

            @childary.each { |child|
                @childhash[child.name] = child
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
            }.join(self.class.splitchar) + self.class.splitchar
        end

        def write
            File.open(@file, "w") { |file|
                file.write(self.to_s)
            }
        end
    end

    class OLine < Blink::Interface
        attr_accessor :fields, :namevar, :splitchar

        @@subclasses = {}

        def OLine.fields=(ary)
            @fields = ary
        end

        def OLine.fields
            return @fields
        end

        #def OLine.newtype(name,splitchar,fields,namevar)
        def OLine.newtype(*args)
            options = [:name, :splitchar, :fields, :namevar]

            arghash = Hash[*args]
            arghash.each { |key,value|
                unless options.include?(key)
                    raise "Invalid argument %s on class %s" %
                        [key,self.class.to_s]
                end
            }
            options.each { |option|
                unless arghash.include?(option)
                    raise "Must pass %s to class %s" %
                        [option,self.class.to_s]
                end
            }
            klassname = arghash[:name].capitalize

            module_eval "
                class %s < OLine
                end" % klassname
            klass = eval(klassname)

            klass.fields = arghash[:fields]
            klass.splitchar = arghash[:splitchar]
            klass.namevar = arghash[:namevar]

            return klass
        end

        def OLine.namevar=(field)
            @namevar = field
        end

        def OLine.namevar
            return @namevar
        end

        def OLine.regex
            return @regex
        end

        def OLine.splitchar=(char)
            @splitchar = char
            @regex = %r{#{char}}
        end

        def OLine.splitchar
            return @splitchar
        end

        def [](field)
            @fields[field]
        end

        def []=(field,value)
            @fields[field] = value
        end

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


        def initialize
            @fields = {}
            if block_given?
                yield self
            end
        end

        def record=(record)
            ary = record.split(self.class.regex)
            self.class.fields.each { |field|
                @fields[field] = ary.shift
                #puts "%s => %s" % [field,@fields[field]]
            }
        end

        def name
            if @fields.include?(self.class.namevar)
                return @fields[self.class.namevar]
            else
                raise "No namevar for objects of type %s" % self.class.to_s
            end
        end

        def to_s
            ary = self.class.fields.collect { |field|
                if ! @fields.include?(field)
                    raise "Object %s is missing field %s" % [self.name,field]
                else
                    @fields[field]
                end
            }.join(self.class.splitchar)
        end
    end
end
