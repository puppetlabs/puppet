class Puppet::Parser::LoadedCode
    def initialize
        @hostclasses = {}
        @definitions = {}
        @nodes = {}

        # So we can keep a list and match the first-defined regex
        @node_list = []
    end

    def <<(thing)
        add(thing)
        self
    end

    def add(instance)
        method = "add_#{instance.type}"
        send(method, instance)
        instance.code_collection = self
        instance
    end

    def add_hostclass(instance)
        dupe_check(instance, @hostclasses) { |dupe| "Class #{instance.name} is already defined#{dupe.error_context}; cannot redefine" }
        dupe_check(instance, @definitions) { |dupe| "Definition #{instance.name} is already defined#{dupe.error_context}; cannot be redefined as a class" }

        @hostclasses[instance.name] = instance
        instance
    end

    def hostclass(name)
        @hostclasses[munge_name(name)]
    end

    def add_node(instance)
        dupe_check(instance, @nodes) { |dupe| "Node #{instance.name} is already defined#{dupe.error_context}; cannot redefine" }

        @node_list << instance
        @nodes[instance.name] = instance
        instance
    end

    def node(name)
        name = munge_name(name)

        if node = @nodes[name]
            return node
        end

        @node_list.each do |node|
            next unless node.name_is_regex?
            return node if node.match(name)
        end
        nil
    end

    def node_exists?(name)
        @nodes[munge_name(name)]
    end

    def nodes?
        @nodes.length > 0
    end

    def add_definition(code)
        @definitions[code.name] = code
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

    def dupe_check(instance, hash)
        return unless dupe = hash[instance.name]
        message = yield dupe
        instance.fail Puppet::ParseError, message
    end
end
