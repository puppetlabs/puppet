# Manage a given node's facts.  This either accepts facts and stores them, or
# returns facts for a given node.
class Puppet::Node::Facts
    # Set up indirection, so that nodes can be looked for in
    # the node sources.
    require 'puppet/indirector'
    extend Puppet::Indirector

    # Use the node source as the indirection terminus.
    indirects :facts, :to => :fact_store

    attr_accessor :name, :values

    def initialize(name, values = {})
        @name = name
        @values = values
    end

    private

    # FIXME These methods are currently unused.

    # Add internal data to the facts for storage.
    def add_internal(facts)
        facts = facts.dup
        facts[:_puppet_timestamp] = Time.now
        facts
    end

    # Strip out that internal data.
    def strip_internal(facts)
        facts = facts.dup
        facts.find_all { |name, value| name.to_s =~ /^_puppet_/ }.each { |name, value| facts.delete(name) }
        facts
    end
end
