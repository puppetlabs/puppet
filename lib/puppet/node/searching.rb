# The module that handles actually searching for nodes.  This is only included
# in the Node class, but it's completely stand-alone functionality, so it's
# worth making it a separate module to simplify testing.
module Puppet::Node::Searching
    # Retrieve a node from the node source, with some additional munging
    # thrown in for kicks.
    def search(key)
        return nil unless key
        if node = cached?(key)
            return node
        end
        facts = node_facts(key)
        node = nil
        names = node_names(key, facts)
        names.each do |name|
            name = name.to_s if name.is_a?(Symbol)
            if node = find(name)
                #Puppet.info "Found %s in %s" % [name, @source]
                break
            end
        end

        # If they made it this far, we haven't found anything, so look for a
        # default node.
        unless node or names.include?("default")
            if node = find("default")
                Puppet.notice "Using default node for %s" % key
            end
        end

        if node
            node.names = names

            cache(node)

            return node
        else
            return nil
        end
    end

    private

    # Store the node to make things a bit faster.
    def cache(node)
        @node_cache ||= {}
        @node_cache[node.name] = node
    end

    # If the node is cached, return it.
    def cached?(name)
        # Don't use cache when the filetimeout is set to 0
        return false if [0, "0"].include?(Puppet[:filetimeout])
        @node_cache ||= {}

        if node = @node_cache[name] and Time.now - node.time < Puppet[:filetimeout]
            return node
        else
            return false
        end
    end

    # Look up the node facts from our fact handler.
    def node_facts(key)
        if facts = Puppet::Node::Facts.find(key)
            facts.values
        else
            {}
        end
    end

    # Calculate the list of node names we should use for looking
    # up our node.
    def node_names(key, facts = nil)
        facts ||= node_facts(key)
        names = []

        if hostname = facts["hostname"]
            unless hostname == key
                names << hostname
            end
        else
            hostname = key
        end

        if fqdn = facts["fqdn"]
            hostname = fqdn
            names << fqdn
        end

        # Make sure both the fqdn and the short name of the
        # host can be used in the manifest
        if hostname =~ /\./
            names << hostname.sub(/\..+/,'')
        elsif domain = facts['domain']
            names << hostname + "." + domain
        end

        # Sort the names inversely by name length.
        names.sort! { |a,b| b.length <=> a.length }

        # And make sure the key is first, since that's the most
        # likely usage.
        ([key] + names).uniq
    end
end
