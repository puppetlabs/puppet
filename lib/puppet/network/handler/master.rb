require 'openssl'
require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/sslcertificates'
require 'xmlrpc/server'
require 'yaml'

class Puppet::Network::Handler
    class MasterError < Puppet::Error; end
    class Master < Handler
        desc "Puppet's configuration interface.  Used for all interactions related to
        generating client configurations."

        include Puppet::Util

        attr_accessor :ast
        attr_reader :ca

        @interface = XMLRPC::Service::Interface.new("puppetmaster") { |iface|
                iface.add_method("string getconfig(string)")
                iface.add_method("int freshness()")
        }

        # Tell a client whether there's a fresh config for it
        def freshness(client = nil, clientip = nil)
            # Always force a recompile.  Newer clients shouldn't do this (as of April 2008).
            Time.now
        end

        def initialize(hash = {})
            args = {}

            if hash[:Local]
                @local = hash[:Local]
            else
                @local = false
            end

            args[:Local] = true

            if hash.include?(:CA) and hash[:CA]
                @ca = Puppet::SSLCertificates::CA.new()
            else
                @ca = nil
            end

            Puppet.debug("Creating interpreter")

            # This is only used by the cfengine module, or if --loadclasses was
            # specified in +puppet+.
            if hash.include?(:Classes)
                args[:Classes] = hash[:Classes]
            end
        end

        # Call our various handlers; this handler is getting deprecated.
        def getconfig(facts, format = "marshal", client = nil, clientip = nil)
            facts = decode_facts(facts)
            client, clientip = clientname(client, clientip, facts)

            # Pass the facts to the fact handler
            Puppet::Node::Facts.new(client, facts).save unless local?

            catalog = Puppet::Node::Catalog.find(client)

            return translate(catalog.extract)
        end

        private

        # Manipulate the client name as appropriate.
        def clientname(name, ip, facts)
            # Always use the hostname from Facter.
            client = facts["hostname"]
            clientip = facts["ipaddress"]
            if Puppet[:node_name] == 'cert'
                if name
                    client = name
                    facts["fqdn"] = client
                    facts["hostname"], facts["domain"] = client.split('.', 2)
                end
                if ip
                    clientip = ip
                end
            end

            return client, clientip
        end

        # 
        def decode_facts(facts)
            if @local
                # we don't need to do anything, since we should already
                # have raw objects
                Puppet.debug "Our client is local"
            else
                Puppet.debug "Our client is remote"

                begin
                    facts = YAML.load(CGI.unescape(facts))
                rescue => detail
                    raise XMLRPC::FaultException.new(
                        1, "Could not rebuild facts"
                    )
                end
            end

            return facts
        end

        # Translate our configuration appropriately for sending back to a client.
        def translate(config)
            if local?
                config
            else
                CGI.escape(config.to_yaml(:UseBlock => true))
            end
        end
    end
end
