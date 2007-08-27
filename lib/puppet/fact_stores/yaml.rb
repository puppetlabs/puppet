Puppet::Util::FactStore.newstore(:yaml) do
    desc "Store client facts as flat files, serialized using YAML."

    # Get a client's facts.
    def get(node)
        file = path(node)

        return nil unless FileTest.exists?(file)

        begin
            facts = YAML::load(File.read(file))
        rescue => detail
            Puppet.err "Could not load facts for %s: %s" % [node, detail]
        end
        facts
    end

    def initialize
        Puppet.config.use(:yamlfacts)
    end

    # Store the facts to disk.
    def set(node, facts)
        File.open(path(node), "w", 0600) do |f|
            begin
                f.print YAML::dump(facts)
            rescue => detail
                Puppet.err "Could not write facts for %s: %s" % [node, detail]
            end
        end
        nil
    end

    private

    # Return the path to a given node's file.
    def path(node)
        File.join(Puppet[:yamlfactdir], node + ".yaml")
    end
end
