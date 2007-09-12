Puppet::Indirector.register_terminus :facts, :yaml do
    desc "Store client facts as flat files, serialized using YAML."

    # Get a client's facts.
    def get(node)
        file = path(node)

        return nil unless FileTest.exists?(file)

        begin
            values = YAML::load(File.read(file))
        rescue => detail
            Puppet.err "Could not load facts for %s: %s" % [node, detail]
        end

        Puppet::Node::Facts.new(node, values)
    end

    def initialize
        Puppet.config.use(:yamlfacts)
    end

    # Store the facts to disk.
    def post(facts)
        File.open(path(facts.name), "w", 0600) do |f|
            begin
                f.print YAML::dump(facts.values)
            rescue => detail
                Puppet.err "Could not write facts for %s: %s" % [facts.name, detail]
            end
        end
        nil
    end

    private

    # Return the path to a given node's file.
    def path(name)
        File.join(Puppet[:yamlfactdir], name + ".yaml")
    end
end
