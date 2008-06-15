require 'puppet/node'
require 'puppet/node/catalog'
require 'puppet/indirector/code'
require 'puppet/parser/interpreter'
require 'yaml'

class Puppet::Node::Catalog::Compiler < Puppet::Indirector::Code
    desc "Puppet's catalog compilation interface, and its back-end is
        Puppet's compiler"

    include Puppet::Util

    attr_accessor :code

    # Compile a node's catalog.
    def find(request)
        unless node = request.options[:node] || find_node(request.key)
            raise ArgumentError, "Could not find node '%s'; cannot compile" % request.key
        end

        if catalog = compile(node)
            return catalog
        else
            # This shouldn't actually happen; we should either return
            # a config or raise an exception.
            return nil
        end
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
    def find_node(key)
        # If we want to use the cert name as our key
        # LAK:FIXME This needs to be figured out somehow, but it requires the routing.
        # This should be able to use the request, yay.
        #if Puppet[:node_name] == 'cert' and client
        #    key = client
        #end

        return nil unless node = Puppet::Node.find(key)

        # Add any external data to the node.
        add_node_data(node)

        node
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

    # Translate our catalog appropriately for sending back to a client.
    # LAK:FIXME This method should probably be part of the protocol, but it
    # shouldn't be here.
    def translate(config)
        unless networked?
            config
        else
            CGI.escape(config.to_yaml(:UseBlock => true))
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
