module Puppet::Util
    # The abstract base class for client configuration storage.
    class ConfigStore
        extend Puppet::Util
        extend Puppet::Util::Docs
        extend Puppet::Util::ClassGen

        @loader = Puppet::Util::Autoload.new(self, "puppet/config_stores")
        @stores = {}

        # Add a new report type.
        def self.newstore(name, options = {}, &block)
            klass = genclass(name,
                :block => block,
                :prefix => "ConfigStore",
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

        # Retrieve the config for a client.
        def get(client)
            raise Puppet::DevError, "%s has not overridden get" % self.class.name
        end

        # Store the config for a client.
        def store(client, config)
            raise Puppet::DevError, "%s has not overridden store" % self.class.name
        end

        def collect_exported(client, conditions)
            raise Puppet::DevError, "%s has not overridden collect_exported" % self.class.name
        end

    end
end

