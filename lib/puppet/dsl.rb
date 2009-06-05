# Just quick mess-around to see what a DSL would look like.
#
# This is what the executable could look like:
##!/usr/bin/env ruby
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

##!/usr/bin/env ruby
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

require 'puppet'

# Provide the actual commands for acting like a language.
module Puppet::DSL
    def aspect(name, options = {}, &block)
        Puppet::DSL::Aspect.new(name, options, &block)
    end

    def acquire(*names)
        names.each do |name|
            if aspect = Puppet::DSL::Aspect[name]
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
        catalog = bucket.to_catalog
        catalog.apply
    end

    def export
        objects = Puppet::DSL::Aspect.collect do |name, aspect|
            if aspect.evaluated?
                aspect.export
            end
        end.reject { |a| a.nil? }.flatten.collect do |obj|
            obj.to_trans
        end
        bucket = Puppet::TransBucket.new(objects)
        bucket.name = "top"
        bucket.type = "class"

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

    class Aspect
        Resource = Puppet::Parser::Resource

        include Puppet::Util
        include Puppet::DSL
        extend Puppet::Util
        extend Enumerable
        attr_accessor :parent, :name, :evaluated

        @aspects = {}

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
            if self.is_a?(Puppet::DSL::Aspect)
                source = self
            else
                source = Puppet::DSL::Aspect[:main]
            end
            unless obj = @@objects[type][name]
                obj = Resource.new :title => name, :type => type.name,
                    :source => source, :scope => scope
                @@objects[type][name] = obj

                @resources << obj
            end

            params.each do |name, value|
                param = Resource::Param.new(
                    :name => name,
                    :value => value,
                    :source => source
                )

                obj.send(:set_parameter, param)
            end

            obj
        end

        def scope
            unless defined?(@scope)
                # Set the code to something innocuous; we just need the
                # scopes, not the interpreter.  Hackish, but true.
                Puppet[:code] = " "
                @interp = Puppet::Parser::Interpreter.new
                require 'puppet/node'
                @node = Puppet::Node.new(Facter.value(:hostname))
                if env = Puppet[:environment] and env == ""
                    env = nil
                end
                @node.parameters = Facter.to_hash
                @compile = Puppet::Parser::Compiler.new(@node, @interp.send(:parser, env))
                @scope = @compile.topscope
            end
            @scope
        end

        def type
            self.name
        end
    end
end

@aspects = {}
