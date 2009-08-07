require 'puppet/node'
require 'puppet/resource/catalog'
require 'puppet/indirector/code'
require 'puppet/parser/interpreter'
require 'yaml'

class Puppet::Resource::Catalog::Compiler < Puppet::Indirector::Code
    desc "Puppet's catalog compilation interface, and its back-end is
        Puppet's compiler"

    include Puppet::Util

    attr_accessor :code

    def extract_facts_from_request(request)
        return unless text_facts = request.options[:facts]
        raise ArgumentError, "Facts but no fact format provided for %s" % request.name unless format = request.options[:facts_format]

        # If the facts were encoded as yaml, then the param reconstitution system
        # in Network::HTTP::Handler will automagically deserialize the value.
        if text_facts.is_a?(Puppet::Node::Facts)
            facts = text_facts
        else
            facts = Puppet::Node::Facts.convert_from(format, text_facts)
        end
        facts.save
    end

    # Compile a node's catalog.
    def find(request)
        extract_facts_from_request(request)

        node = node_from_request(request)

        if catalog = compile(node)
            return catalog
        else
            # This shouldn't actually happen; we should either return
            # a config or raise an exception.
            return nil
        end
    end

    # filter-out a catalog to remove exported resources
    def filter(catalog)
        return catalog.filter { |r| r.virtual? } if catalog.respond_to?(:filter)
        catalog
    end

    def initialize
        set_server_facts
    end

    # Create/return our interpreter.
    def interpreter
        unless defined?(@interpreter) and @interpreter
            @interpreter = create_interpreter
        end
        @interpreter
    end

    # Is our compiler part of a network, or are we just local?
    def networked?
        $0 =~ /puppetmasterd/
    end

    private

    # Add any extra data necessary to the node.
    def add_node_data(node)
        # Merge in our server-side facts, so they can be used during compilation.
        node.merge(@server_facts)
    end

    # Compile the actual catalog.
    def compile(node)
        # Ask the interpreter to compile the catalog.
        str = "Compiled catalog for %s" % node.name
        if node.environment
            str += " in environment %s" % node.environment
        end
        config = nil

        loglevel = networked? ? :notice : :none

        benchmark(loglevel, "Compiled catalog for %s" % node.name) do
            begin
                config = interpreter.compile(node)
            rescue Puppet::Error => detail
                Puppet.err(detail.to_s) if networked?
                raise
            end
        end

        return config
    end

    # Create our interpreter object.
    def create_interpreter
        return Puppet::Parser::Interpreter.new
    end

    # Turn our host name into a node object.
    def find_node(name)
        begin
            return nil unless node = Puppet::Node.find(name)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            raise Puppet::Error, "Failed when searching for node %s: %s" % [name, detail]
        end


        # Add any external data to the node.
        add_node_data(node)

        node
    end

    # Extract the node from the request, or use the request
    # to find the node.
    def node_from_request(request)
        if node = request.options[:use_node]
            return node
        end

        # If the request is authenticated, then the 'node' info will
        # be available; if not, then we use the passed-in key.  We rely
        # on our authorization system to determine whether this is allowed.
        name = request.node || request.key
        if node = find_node(name)
            return node
        end

        raise ArgumentError, "Could not find node '%s'; cannot compile" % name
    end

    # Initialize our server fact hash; we add these to each client, and they
    # won't change while we're running, so it's safe to cache the values.
    def set_server_facts
        @server_facts = {}

        # Add our server version to the fact list
        @server_facts["serverversion"] = Puppet.version.to_s

        # And then add the server name and IP
        {"servername" => "fqdn",
            "serverip" => "ipaddress"
        }.each do |var, fact|
            if value = Facter.value(fact)
                @server_facts[var] = value
            else
                Puppet.warning "Could not retrieve fact %s" % fact
            end
        end

        if @server_facts["servername"].nil?
            host = Facter.value(:hostname)
            if domain = Facter.value(:domain)
                @server_facts["servername"] = [host, domain].join(".")
            else
                @server_facts["servername"] = host
            end
        end
    end

    # Mark that the node has checked in. LAK:FIXME this needs to be moved into
    # the Node class, or somewhere that's got abstract backends.
    def update_node_check(node)
        if Puppet.features.rails? and Puppet[:storeconfigs]
            Puppet::Rails.connect

            host = Puppet::Rails::Host.find_or_create_by_name(node.name)
            host.last_freshcheck = Time.now
            host.save
        end
    end
end
