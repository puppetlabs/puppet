# Just quick mess-around to see what a DSL would look like.
# 
# This is what the executable could look like:
##!/usr/bin/ruby
#
#require 'puppet'
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
#
# require 'puppet'
# require 'puppet/dsl'
# 
# include Puppet::DSL
# init()
# 
# aspect :webserver do
#     file "/tmp/testone", :content => "yaytest"
# 
#     exec "testing", :command => "/bin/echo this is a test"
# end
# 
# aspect :other, :inherits => :webserver do
#     file "/tmp/testone", :mode => "755"
# end
# 
# acquire :other
# 
# apply

module Puppet
    # Provide the actual commands for acting like a language.
    module DSL
        def aspect(name, options = {}, &block)
            Puppet::Aspect.new(name, options, &block)
        end

        def acquire(*names)
            names.each do |name|
                if aspect = Puppet::Aspect[name]
                    unless aspect.evaluated?
                        aspect.evaluate
                    end
                else
                    raise "Could not find aspect %s" % name
                end
            end
        end

        def apply
            bucket = export()
            objects = bucket.to_type
            master = Puppet::Network::Client.master.new :Master => "whatever"
            master.objects = objects

            master.apply
        end

        def export
            objects = Puppet::Aspect.collect do |name, aspect|
                if aspect.evaluated?
                    aspect.export
                end
            end.reject { |a| a.nil? }.flatten.collect do |obj|
                obj.to_trans
            end
            bucket = Puppet::TransBucket.new(objects)
            bucket.name = "top"

            return bucket
        end

        def init
            unless Process.uid == 0
                Puppet[:confdir] = File.expand_path("~/.puppet")
                Puppet[:vardir] = File.expand_path("~/.puppet/var")
            end
            Puppet[:user] = Process.uid
            Puppet[:group] = Process.gid
            Puppet::Util::Log.newdestination(:console)
            Puppet::Util::Log.level = :info
        end

        private
    end

    class Aspect
        Resource = Puppet::Parser::Resource

        include Puppet::Util
        include Puppet::DSL
        extend Puppet::Util
        extend Enumerable
        attr_accessor :parent, :name, :evaluated

        @aspects = {}

        # For now, just do some hackery so resources work
        @@interp = Puppet::Parser::Interpreter.new :Code => ""
        @@scope = Puppet::Parser::Scope.new(:interp => @@interp)

        @@objects = Hash.new do |hash, key|
            hash[key] = {}
        end

        # Create an instance method for every type
        Puppet::Type.loadall
        Puppet::Type.eachtype do |type|
            define_method(type.name) do |*args|
                newresource(type, *args)
            end
        end

        def self.[]=(name, aspect)
            name = symbolize(name)
            @aspects[name] = aspect
        end

        def self.[](name)
            name = symbolize(name)

            # Make sure there's always a main.  This can get deleted in testing.
            if name == :main and ! @aspects[name]
                new(:main) {}
            end
            @aspects[name]
        end

        def self.clear
            @aspects.clear
            @@objects.clear
        end

        def self.delete(name)
            name = symbolize(name)
            if @aspects.has_key?(name)
                @aspects.delete(name)
            end
        end

        def self.each
            @aspects.each do |name, a|
                yield name, a
            end
        end

        def child_of?(aspect)
            unless aspect.is_a?(self.class)
                obj = self.class[aspect]
                unless obj
                    raise "Could not find aspect %s" % aspect
                end
                aspect = obj
            end
            if self.parent
                if self.parent == aspect
                    return true
                elsif self.parent.child_of?(aspect)
                    return true
                else
                    return false
                end
            else
                return false
            end
        end

        def evaluate
            if self.parent and ! self.parent.evaluated?
                self.parent.evaluate
            end

            unless evaluated?
                if defined? @block
                    instance_eval(&@block)
                end
                @evaluated = true
            end
        end

        def evaluated?
            if self.evaluated
                true
            else
                false
            end
        end

        def export
            @resources.dup
        end

        def initialize(name, options = {}, &block)
            name = symbolize(name)
            @name = name
            if block
                @block = block
            end
            if pname = options[:inherits]
                if pname.is_a?(self.class)
                    @parent = pname
                elsif parent = self.class[pname]
                    @parent = parent
                else
                    raise "Could not find parent aspect %s" % pname
                end
            end

            @resources = []

            self.class[name] = self
        end

        def newresource(type, name, params = {})
            if self.is_a?(Puppet::Aspect)
                source = self
            else
                source = Puppet::Aspect[:main]
            end
            unless obj = @@objects[type][name]
                obj = Resource.new :title => name, :type => type.name,
                    :source => source, :scope => @@scope
                @@objects[type][name] = obj

                @resources << obj
            end

            params.each do |name, value|
                param = Resource::Param.new(
                    :name => name,
                    :value => value,
                    :source => source
                )

                obj.set(param)
            end

            obj
        end

        def type
            self.name
        end
    end
end

@aspects = {}

class Puppet::DisabledDSL
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
