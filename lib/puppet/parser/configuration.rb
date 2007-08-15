#  Created by Luke A. Kanies on 2007-08-13.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/external/gratr/digraph'
require 'puppet/external/gratr/import'
require 'puppet/external/gratr/dot'

# Maintain a graph of scopes, along with a bunch of data
# about the individual configuration we're compiling.
class Puppet::Parser::Configuration
    attr_reader :topscope, :interpreter, :host, :facts

    # Add a collection to the global list.
    def add_collection(coll)
        @collections << coll
    end

    # Store the fact that we've evaluated a class, and store a reference to
    # the scope in which it was evaluated, so that we can look it up later.
    def class_set(name, scope)
        @class_scopes[name] = scope
    end

    # Return the scope associated with a class.  This is just here so
    # that subclasses can set their parent scopes to be the scope of
    # their parent class, and it's also used when looking up qualified
    # variables.
    def class_scope(klass)
        # They might pass in either the class or class name
        if klass.respond_to?(:classname)
            @class_scopes[klass.classname]
        else
            @class_scopes[klass]
        end
    end

    # Return a list of all of the defined classes.
    def classlist
        return @class_scopes.keys.reject { |k| k == "" }
    end

    # Should the scopes behave declaratively?
    def declarative?
        true
    end

    # Set up our configuration.  We require an interpreter
    # and a host name, and we normally are passed facts, too.
    def initialize(options)
        @interpreter = options[:interpreter] or
            raise ArgumentError, "You must pass an interpreter to the configuration"
        @facts = options[:facts] || {}
        @host = options[:host] or
            raise ArgumentError, "You must pass a host name to the configuration"

        # Call the setup methods from the base class.
        super()

        initvars()
    end

    # Create a new scope, with either a specified parent scope or
    # using the top scope.  Adds an edge between the scope and
    # its parent to the graph.
    def newscope(parent = nil)
        parent ||= @topscope
        scope = Puppet::Parser::Scope.new(:configuration => self)
        @graph.add_edge!(parent, scope)
        scope
    end

    # Find the parent of a given scope.  Assumes scopes only ever have
    # one in edge, which will always be true.
    def parent(scope)
        if ary = @graph.adjacent(scope, :direction => :in) and ary.length > 0
            ary[0]
        else
            nil
        end
    end

    # Return an array of all of the unevaluated objects
    def unevaluated
        ary = @definedtable.find_all do |name, object|
            ! object.builtin? and ! object.evaluated?
        end.collect { |name, object| object }

        if ary.empty?
            return nil
        else
            return ary
        end
    end

    private

    # Set up all of our internal variables.
    def initvars
        # The table for storing class singletons.  This will only actually
        # be used by top scopes and node scopes.
        @class_scopes = {}

        # The table for all defined resources.
        @resource_table = {}

        # The list of objects that will available for export.
        @exported_resources = {}

        # The list of overrides.  This is used to cache overrides on objects
        # that don't exist yet.  We store an array of each override.
        @resource_overrides = Hash.new do |overs, ref|
            overs[ref] = []
        end

        # The list of collections that have been created.  This is a global list,
        # but they each refer back to the scope that created them.
        @collections = []

        # Create our initial scope, our scope graph, and add the initial scope to the graph.
        @topscope = Puppet::Parser::Scope.new(:configuration => self, :type => "main", :name => "top")
        @graph = GRATR::Digraph.new
        @graph.add_vertex!(@topscope)
    end

    # Return the list of remaining overrides.
    def overrides
        @resource_overrides.values.flatten
    end

    def resources
        @resourcetable
    end
end
