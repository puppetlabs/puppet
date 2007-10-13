require 'puppet/node'
require 'puppet/node/configuration'
require 'puppet/indirector/code'
require 'puppet/parser/interpreter'
require 'yaml'

class Puppet::Indirector::Code::Configuration < Puppet::Indirector::Code
    desc "Puppet's configuration compilation interface.  Passed a node name
        or other key, retrieves information about the node (using the ``node_source``)
        and returns a compiled configuration."

    include Puppet::Util

    attr_accessor :code

    # Compile a node's configuration.
    def find(key, client = nil, clientip = nil)
        if key.is_a?(Puppet::Node)
            node = key
        else
            node = find_node(key)
        end

        if configuration = compile(node)
            return configuration.to_transportable
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

    # Return the configuration version.  Here we're returning the
    # latest of the node, fact, or parse date.  These are the
    # three things that go into compiling a client configuration,
    # so changes in any of them result in changes.
    # LAK:FIXME Note that this only works when all three sources
    # use timestamps; once one of them moves to using real versions,
    # the comparison stops working.
    def version(key)
        if node = Puppet::Node.search(key)
            return [Puppet::Node.version(key).to_f, Puppet::Node::Facts.version(key).to_f, interpreter.configuration_version(node).to_f].sort[-1]
        else
            # This is the standard for "got nothing for ya".
            0
        end
    end

    private

    # Add any extra data necessary to the node.
    def add_node_data(node)
        # Merge in our server-side facts, so they can be used during compilation.
        node.merge(@server_facts)
    end

    # Compile the actual configuration.
    def compile(node)
        # Ask the interpreter to compile the configuration.
        str = "Compiled configuration for %s" % node.name
        if node.environment
            str += " in environment %s" % node.environment
        end
        config = nil

        loglevel = networked? ? :notice : :none

        benchmark(loglevel, "Compiled configuration for %s" % node.name) do
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
        #if Puppet[:node_name] == 'cert' and client
        #    key = client
        #end

        # Note that this is reasonable, because either their node source should actually
        # know about the node, or they should be using the ``none`` node source, which
        # will always return data.
        unless node = Puppet::Node.search(key)
            raise Puppet::Error, "Could not find node '%s'" % key
        end

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

    # Translate our configuration appropriately for sending back to a client.
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
