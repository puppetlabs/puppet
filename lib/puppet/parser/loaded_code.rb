class Puppet::Parser::LoadedCode
    def initialize
        @hostclasses = {}
        @definitions = {}
        @nodes = {}
    end

    def add_hostclass(name, code)
        @hostclasses[munge_name(name)] = code
    end

    def hostclass(name)
        @hostclasses[munge_name(name)]
    end

    def add_node(name, code)
        @nodes[check_name(name)] = code
    end

    def node(name)
        name = check_name(name)
        unless node = @nodes[name]
            @nodes.each do |nodename, n|
                if nodename.regex? and nodename.match(name)
                    return n
                end
            end
        end
        node
    end

    def nodes?
        @nodes.length > 0
    end

    def add_definition(name, code)
        @definitions[munge_name(name)] = code
    end

    def definition(name)
        @definitions[munge_name(name)]
    end

    def find(namespace, name, type)
        if r = find_fully_qualified(name, type)
            return r
        end

        ary = namespace.split("::")

        while ary.length > 0
            tmp_namespace = ary.join("::")
            if r = find_partially_qualified(tmp_namespace, name, type)
                return r
            end

            # Delete the second to last object, which reduces our namespace by one.
            ary.pop
        end

        send(type, name)
    end

    def find_node(name)
        find("", name, :node)
    end

    def find_hostclass(namespace, name)
        find(namespace, name, :hostclass)
    end

    def find_definition(namespace, name)
        find(namespace, name, :definition)
    end

    [:hostclasses, :nodes, :definitions].each do |m|
        define_method(m) do
            instance_variable_get("@#{m}").dup
        end
    end

    private

    def find_fully_qualified(name, type)
        return nil unless name =~ /^::/

        name = name.sub(/^::/, '')

        send(type, name)
    end

    def find_partially_qualified(namespace, name, type)
        send(type, [namespace, name].join("::"))
    end

    def munge_name(name)
        name.to_s.downcase
    end

    # Check that the given (node) name is an HostName instance
    # We're doing this so that hashing of node in the @nodes hash
    # is consistent (see AST::HostName#hash and AST::HostName#eql?)
    # and that the @nodes hash still keep its O(1) get/put properties.
    def check_name(name)
        name = Puppet::Parser::AST::HostName.new(:value => name) unless name.is_a?(Puppet::Parser::AST::HostName)
        name
    end
end
