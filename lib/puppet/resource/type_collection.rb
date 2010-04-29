class Puppet::Resource::TypeCollection
    attr_reader :environment

    def clear
        @hostclasses.clear
        @definitions.clear
        @nodes.clear
    end

    def initialize(env)
        @environment = env.is_a?(String) ? Puppet::Node::Environment.new(env) : env
        @hostclasses = {}
        @definitions = {}
        @nodes = {}

        # So we can keep a list and match the first-defined regex
        @node_list = []

        @watched_files = {}
    end

    def <<(thing)
        add(thing)
        self
    end

    def add(instance)
        if instance.type == :hostclass and other = @hostclasses[instance.name] and other.type == :hostclass
            other.merge(instance)
            return other
        end
        method = "add_#{instance.type}"
        send(method, instance)
        instance.resource_type_collection = self
        instance
    end

    def add_hostclass(instance)
        dupe_check(instance, @hostclasses) { |dupe| "Class '#{instance.name}' is already defined#{dupe.error_context}; cannot redefine" }
        dupe_check(instance, @definitions) { |dupe| "Definition '#{instance.name}' is already defined#{dupe.error_context}; cannot be redefined as a class" }

        @hostclasses[instance.name] = instance
        instance
    end

    def hostclass(name)
        @hostclasses[munge_name(name)]
    end

    def add_node(instance)
        dupe_check(instance, @nodes) { |dupe| "Node '#{instance.name}' is already defined#{dupe.error_context}; cannot redefine" }

        @node_list << instance
        @nodes[instance.name] = instance
        instance
    end

    def loader
        require 'puppet/parser/type_loader'
        @loader ||= Puppet::Parser::TypeLoader.new(environment)
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

    def add_definition(instance)
        dupe_check(instance, @hostclasses) { |dupe| "'#{instance.name}' is already defined#{dupe.error_context} as a class; cannot redefine as a definition" }
        dupe_check(instance, @definitions) { |dupe| "Definition '#{instance.name}' is already defined#{dupe.error_context}; cannot be redefined" }
        @definitions[instance.name] = instance
    end

    def definition(name)
        @definitions[munge_name(name)]
    end

    def find(namespaces, name, type)
        #Array("") == [] for some reason
        namespaces = [namespaces] unless namespaces.is_a?(Array)

        if r = find_fully_qualified(name, type)
            return r
        end

        namespaces.each do |namespace|
            ary = namespace.split("::")

            while ary.length > 0
                tmp_namespace = ary.join("::")
                if r = find_partially_qualified(tmp_namespace, name, type)
                    return r
                end

                # Delete the second to last object, which reduces our namespace by one.
                ary.pop
            end

            if result = send(type, name)
                return result
            end
        end
        nil
    end

    def find_or_load(namespaces, name, type)
        name      = name.downcase
        namespaces = [namespaces] unless namespaces.is_a?(Array)
        namespaces = namespaces.collect { |ns| ns.downcase }

        # This could be done in the load_until, but the knowledge seems to
        # belong here.
        if r = find(namespaces, name, type)
            return r
        end

        return loader.load_until(namespaces, name) { find(namespaces, name, type) }
    end

    def find_node(name)
        find("", name, :node)
    end

    def find_hostclass(namespaces, name)
        find_or_load(namespaces, name, :hostclass)
    end

    def find_definition(namespaces, name)
        find_or_load(namespaces, name, :definition)
    end

    [:hostclasses, :nodes, :definitions].each do |m|
        define_method(m) do
            instance_variable_get("@#{m}").dup
        end
    end

    def perform_initial_import
        parser = Puppet::Parser::Parser.new(environment)
        if code = Puppet.settings.uninterpolated_value(:code, environment.to_s) and code != ""
            parser.string = code
        else
            file = Puppet.settings.value(:manifest, environment.to_s)
            return unless File.exist?(file)
            parser.file = file
        end
        parser.parse
    rescue => detail
        msg = "Could not parse for environment #{environment}: #{detail}"
        error = Puppet::Error.new(msg)
        error.set_backtrace(detail.backtrace)
        raise error
    end

    def stale?
        @watched_files.values.detect { |file| file.changed? }
    end

    def version
        return @version if defined?(@version)

        if environment[:config_version] == ""
            @version = Time.now.to_i
            return @version
        end

        @version = Puppet::Util.execute([environment[:config_version]]).strip

    rescue Puppet::ExecutionFailure => e
        raise Puppet::ParseError, "Unable to set config_version: #{e.message}"
    end

    def watch_file(file)
        @watched_files[file] = Puppet::Util::LoadedFile.new(file)
    end

    def watching_file?(file)
        @watched_files.include?(file)
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
