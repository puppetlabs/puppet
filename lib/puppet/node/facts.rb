require 'puppet/node'
require 'puppet/indirector'

# Manage a given node's facts.  This either accepts facts and stores them, or
# returns facts for a given node.
class Puppet::Node::Facts
    # Set up indirection, so that nodes can be looked for in
    # the node sources.
    extend Puppet::Indirector

    # We want to expire any cached nodes if the facts are saved.
    module NodeExpirer
        def save(instance, *args)
            Puppet::Node.expire(instance.name)
            super
        end
    end

    # Use the node source as the indirection terminus.
    indirects :facts, :terminus_class => :facter, :extend => NodeExpirer

    attr_accessor :name, :values

    def initialize(name, values = {})
        @name = name
        @values = values

        add_internal
    end

    private

    # Add internal data to the facts for storage.
    def add_internal
        self.values[:_timestamp] = Time.now
    end

    # Strip out that internal data.
    def strip_internal
        newvals = values.dup
        newvals.find_all { |name, value| name.to_s =~ /^_/ }.each { |name, value| newvals.delete(name) }
        newvals
    end
end
