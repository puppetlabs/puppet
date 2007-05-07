require 'yaml'
require 'puppet/util/fact_store'

class Puppet::Network::Handler
    # Receive logs from remote hosts.
    class Facts < Handler
        desc "An interface for storing and retrieving client facts.  Currently only
        used internally by Puppet."

        @interface = XMLRPC::Service::Interface.new("facts") { |iface|
            iface.add_method("void set(string, string)")
            iface.add_method("string get(string)")
            iface.add_method("integer store_date(string)")
        }

        def initialize(hash = {})
            super

            backend = Puppet[:factstore]

            unless klass = Puppet::Util::FactStore.store(backend)
                raise Puppet::Error, "Could not find fact store %s" % backend
            end

            @backend = klass.new
        end

        # Get the facts from our back end.
        def get(node)
            if facts = @backend.get(node)
                return strip_internal(facts)
            else
                return nil
            end
        end

        # Set the facts in the backend.
        def set(node, facts)
            @backend.set(node, add_internal(facts))
            nil
        end

        # Retrieve a client's storage date.
        def store_date(node)
            if facts = get(node)
                facts[:_puppet_timestamp].to_i
            else
                nil
            end
        end

        private

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
end

# $Id$
