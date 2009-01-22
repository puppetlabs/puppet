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

    def add_local_facts
        values["clientversion"] = Puppet.version.to_s
        values["environment"] ||= Puppet.settings[:environment]
    end

    def initialize(name, values = {})
        @name = name
        @values = values

        add_internal
    end

    def downcase_if_necessary
        return unless Puppet.settings[:downcasefacts]

        Puppet.warning "DEPRECATION NOTICE: Fact downcasing is deprecated; please disable (20080122)"
        values.each do |fact, value|
            values[fact] = value.downcase if value.is_a?(String)
        end
    end

    # Convert all fact values into strings.
    def stringify
        values.each do |fact, value|
            values[fact] = value.to_s
        end
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
