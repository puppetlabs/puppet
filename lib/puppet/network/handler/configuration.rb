require 'openssl'
require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/sslcertificates'
require 'xmlrpc/server'
require 'yaml'

class Puppet::Network::Handler
    class Configuration < Handler
        desc "Puppet's configuration compilation interface.  Passed a node name
            or other key, retrieves information about the node (using the ``node_source``)
            and returns a compiled configuration."

        include Puppet::Util

        attr_accessor :local

        @interface = XMLRPC::Service::Interface.new("configuration") { |iface|
                iface.add_method("string configuration(string)")
                iface.add_method("string version()")
        }

        # Compile a node's configuration.
        def configuration(key, client = nil, clientip = nil)
            # Note that this is reasonable, because either their node source should actually
            # know about the node, or they should be using the ``none`` node source, which
            # will always return data.
            unless node = node_handler.details(key)
                raise Puppet::Error, "Could not find node '%s'" % key
            end

            # Add any external data to the node.
            add_node_data(node)

            return translate(compile(node))
        end

        def initialize(options = {})
            if options[:Local]
                @local = options[:Local]
            else
                @local = false
            end

            # Just store the options, rather than creating the interpreter
            # immediately.  Mostly, this is so we can create the interpreter
            # on-demand, which is easier for testing.
            @options = options

            set_server_facts
        end

        # Are we running locally, or are our clients networked?
        def local?
            self.local
        end

        # Return the configuration version.
        def version(client = nil, clientip = nil)
            v = interpreter.parsedate
            # If we can find the node, then store the fact that the node
            # has checked in.
            if client and node = node_handler.details(client)
                update_node_check(node)
            end

            return v
        end

        private

        # Add any extra data necessary to the node.
        def add_node_data(node)
            # Merge in our server-side facts, so they can be used during compilation.
            node.fact_merge(@server_facts)

            # Add any specified classes to the node's class list.
            if classes = @options[:Classes]
                classes.each do |klass|
                    node.classes << klass
                end
            end
        end

        # Compile the actual configuration.
        def compile(node)
            # Pick the benchmark level.
            if local?
                level = :none
            else
                level = :notice
            end

            # Ask the interpreter to compile the configuration.
            config = nil
            benchmark(level, "Compiled configuration for %s" % node.name) do
                begin
                    config = interpreter.compile(node)
                rescue Puppet::Error => detail
                    if Puppet[:trace]
                        puts detail.backtrace
                    end
                    Puppet.err detail
                    raise XMLRPC::FaultException.new(
                        1, detail.to_s
                    )
                end
            end

            return config
        end

        # Create our interpreter object.
        def create_interpreter(options)
            args = {}

            # Allow specification of a code snippet or of a file
            if code = options[:Code]
                args[:Code] = code
            else
                args[:Manifest] = options[:Manifest] || Puppet[:manifest]
            end

            args[:Local] = local?

            if options.include?(:UseNodes)
                args[:UseNodes] = options[:UseNodes]
            elsif @local
                args[:UseNodes] = false
            end

            # This is only used by the cfengine module, or if --loadclasses was
            # specified in +puppet+.
            if options.include?(:Classes)
                args[:Classes] = options[:Classes]
            end

            return Puppet::Parser::Interpreter.new(args)
        end

        # Create/return our interpreter.
        def interpreter
            unless defined?(@interpreter) and @interpreter
                @interpreter = create_interpreter(@options)
            end
            @interpreter
        end

        # Create a node handler instance for looking up our nodes.
        def node_handler
            unless defined?(@node_handler)
                @node_handler = Puppet::Network::Handler.handler(:node).new
            end
            @node_handler
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
        def translate(config)
            if local?
                config
            else
                CGI.escape(config.to_yaml(:UseBlock => true))
            end
        end

        # Mark that the node has checked in. FIXME this needs to be moved into
        # the SimpleNode class, or somewhere that's got abstract backends.
        def update_node_check(node)
            if Puppet.features.rails? and Puppet[:storeconfigs]
                Puppet::Rails.connect

                host = Puppet::Rails::Host.find_or_create_by_name(node.name)
                host.last_freshcheck = Time.now
                host.save
            end
        end
    end
end

# $Id$
