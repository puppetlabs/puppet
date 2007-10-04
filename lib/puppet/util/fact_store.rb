# Created on 2007-05-02
# Copyright Luke Kanies

module Puppet::Util
    # The abstract base class for client fact storage.
    class FactStore
        extend Puppet::Util
        extend Puppet::Util::Docs
        extend Puppet::Util::ClassGen

        @loader = Puppet::Util::Autoload.new(self, "puppet/fact_stores")
        @stores = {}

        # Add a new report type.
        def self.newstore(name, options = {}, &block)
            klass = genclass(name,
                :block => block,
                :prefix => "FactStore",
                :hash => @stores,
                :attributes => options
            )
        end

        # Remove a store; really only used for testing.
        def self.rmstore(name)
            rmclass(name, :hash => @stores)
        end

        # Load a store.
        def self.store(name)
            name = symbolize(name)
            unless @stores.include? name
                if @loader.load(name)
                    unless @stores.include? name
                        Puppet.warning(
                            "Loaded report file for %s but report was not defined" %
                            name
                        )
                        return nil
                    end
                else
                    return nil
                end
            end
            @stores[name]
        end

        # Retrieve the facts for a node.
        def get(node)
            raise Puppet::DevError, "%s has not overridden get" % self.class.name
        end

        # Set the facts for a node.
        def set(node, facts)
            raise Puppet::DevError, "%s has not overridden set" % self.class.name
        end
    end
end

