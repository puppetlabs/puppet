# Just quick mess-around to see what a DSL would look like.
# 
# This is what the executable could look like:
##!/usr/bin/ruby
#
#require 'puppet'
#
#require 'puppet/dsl'
#
#Puppet::DSL.import(ARGV[0])
#
#bucket = Puppet::TransBucket.new
#bucket.type = "top"
#bucket.keyword = "class"
#
#Puppet::DSL.find_all do |name, sub|
#    sub.included
#end.each do |name, sub|
#    bucket.push sub.export
#end
#
#puts bucket.to_manifest
#
# And here's what an example config could look like:
#

##!/usr/bin/ruby
#
#class Base
#    file "/etc/passwd",
#        :owner => "root",
#        :group => "root",
#        :mode => 0644,
#        :source => "puppet://puppet/..."
#
#
#
#end
#
#class BSD < Base
#    file "/etc/passwd",
#        :group => "wheel"
#end
#
#include :bsd
#

class Puppet::DSL
    @@subs = {}
    @name = :DSLClass
    class << self
        include Enumerable
        attr_accessor :included, :name, :objects

        def each
            @@subs.each do |name, sub|
                yield name, sub
            end
        end

        def export
            bucket = nil
            if superclass() != Puppet::DSL
                bucket = superclass.export
            else
                bucket = Puppet::TransBucket.new
                bucket.keyword = "class"
                bucket.type = self.name
            end

            @objects.each do |type, ary|
                ary.each do |name, obj|
                    if pobj = bucket.find { |sobj| obj.name == sobj.name &&  obj.type == sobj.type }
                        obj.each do |param, value|
                            pobj[param] = value
                        end
                    else
                        bucket.push obj
                    end
                end
            end

            return bucket
        end

        def include(name)
            if ary = @@subs.find { |n, s| n == name }
                ary[1].included = true
            else
                raise "Could not find class %s" % name
            end
        end

        def inherited(sub)
            name = sub.to_s.downcase.gsub(/.+::/, '').intern
            @@subs[name] = sub
            sub.name = name
            sub.initvars

            sub
        end

        def initvars
            #if superclass() == Puppet::DSL
                @objects = {}
            #else
            #    @objects = superclass.objects
            #end
        end


        def import(file)
            text = File.read(file)
            # If they don't specify a parent class, then specify one
            # for them.
            text.gsub!(/^class \S+\s*$/) do |match|
                "#{match} < Puppet::DSL"
            end
            eval(text, binding)
        end

        def method_missing(method, *args)
            if klass = Puppet::Type.type(method)
                method = method.intern if method.is_a? String
                @objects[method] ||= {}

                names = args.shift
                hash = args.shift
                names = [names] unless names.is_a? Array
                names.each do |name|
                    unless obj = @objects[method][name]
                        obj = Puppet::TransObject.new(name, method)
                        @objects[method][name] = obj
                    end

                    hash.each do |param, value|
                        if obj[param]
                            raise "Cannot override %s in %s[%s]" %
                                [param, method, name]
                        else
                            obj[param] = value
                        end
                    end
                end
            else
                raise "No type %s" % method
            end
        end
    end
end

# $Id$
