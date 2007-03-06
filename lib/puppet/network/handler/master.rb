require 'openssl'
require 'puppet'
require 'puppet/parser/interpreter'
require 'puppet/sslcertificates'
require 'xmlrpc/server'
require 'yaml'

class Puppet::Network::Handler
    class MasterError < Puppet::Error; end
    class Master < Handler
        include Puppet::Util

        attr_accessor :ast, :local
        attr_reader :ca

        @interface = XMLRPC::Service::Interface.new("puppetmaster") { |iface|
                iface.add_method("string getconfig(string)")
                iface.add_method("int freshness()")
        }

        # FIXME At some point, this should be autodocumenting.
        def addfacts(facts)
            # Add our server version to the fact list
            facts["serverversion"] = Puppet.version.to_s

            # And then add the server name and IP
            {"servername" => "hostname",
                "serverip" => "ipaddress"
            }.each do |var, fact|
                if obj = Facter[fact]
                    facts[var] = obj.value
                else
                    Puppet.warning "Could not retrieve fact %s" % fact
                end
            end
        end

        # Manipulate the client name as appropriate.
        def clientname(name, ip, facts)
            # Always use the hostname from Facter.
            client = facts["hostname"]
            clientip = facts["ipaddress"]
            if Puppet[:node_name] == 'cert'
                if name
                    client = name
                end
                if ip
                    clientip = ip
                end
            end

            return client, clientip
        end

        # Tell a client whether there's a fresh config for it
        def freshness(client = nil, clientip = nil)
            if Puppet.features.rails? and Puppet[:storeconfigs]
                Puppet::Rails.connect

                host = Puppet::Rails::Host.find_or_create_by_name(client)
                host.last_freshcheck = Time.now
                if clientip and (! host.ip or host.ip == "")
                    host.ip = clientip
                end
                host.save
            end
            if defined? @interpreter
                return @interpreter.parsedate
            else
                return 0
            end
        end

        def initialize(hash = {})
            args = {}

            # Allow specification of a code snippet or of a file
            if code = hash[:Code]
                args[:Code] = code
            else
                args[:Manifest] = hash[:Manifest] || Puppet[:manifest]
            end

            if hash[:Local]
                @local = hash[:Local]
            else
                @local = false
            end

            args[:Local] = @local

            if hash.include?(:CA) and hash[:CA]
                @ca = Puppet::SSLCertificates::CA.new()
            else
                @ca = nil
            end

            Puppet.debug("Creating interpreter")

            if hash.include?(:UseNodes)
                args[:UseNodes] = hash[:UseNodes]
            elsif @local
                args[:UseNodes] = false
            end

            # This is only used by the cfengine module, or if --loadclasses was
            # specified in +puppet+.
            if hash.include?(:Classes)
                args[:Classes] = hash[:Classes]
            end

            @interpreter = Puppet::Parser::Interpreter.new(args)
        end

        def getconfig(facts, format = "marshal", client = nil, clientip = nil)
            if @local
                # we don't need to do anything, since we should already
                # have raw objects
                Puppet.debug "Our client is local"
            else
                Puppet.debug "Our client is remote"

                # XXX this should definitely be done in the protocol, somehow
                case format
                when "marshal":
                    Puppet.warning "You should upgrade your client.  'Marshal' will not be supported much longer."
                    begin
                        facts = Marshal::load(CGI.unescape(facts))
                    rescue => detail
                        raise XMLRPC::FaultException.new(
                            1, "Could not rebuild facts"
                        )
                    end
                when "yaml":
                    begin
                        facts = YAML.load(CGI.unescape(facts))
                    rescue => detail
                        raise XMLRPC::FaultException.new(
                            1, "Could not rebuild facts"
                        )
                    end
                else
                    raise XMLRPC::FaultException.new(
                        1, "Unavailable config format %s" % format
                    )
                end
            end

            client, clientip = clientname(client, clientip, facts)

            # Add any server-side facts to our server.
            addfacts(facts)

            retobjects = nil

            # This is hackish, but there's no "silence" option for benchmarks
            # right now
            if @local
                #begin
                    retobjects = @interpreter.run(client, facts)
                #rescue Puppet::Error => detail
                #    Puppet.err detail
                #    raise XMLRPC::FaultException.new(
                #        1, detail.to_s
                #    )
                #rescue => detail
                #    Puppet.err detail.to_s
                #    return ""
                #end
            else
                benchmark(:notice, "Compiled configuration for %s" % client) do
                    begin
                        retobjects = @interpreter.run(client, facts)
                    rescue Puppet::Error => detail
                        Puppet.err detail
                        raise XMLRPC::FaultException.new(
                            1, detail.to_s
                        )
                    rescue => detail
                        Puppet.err detail.to_s
                        return ""
                    end
                end
            end

            if @local
                return retobjects
            else
                str = nil
                case format
                when "marshal":
                    str = Marshal::dump(retobjects)
                when "yaml":
                    str = YAML.dump(retobjects)
                else
                    raise XMLRPC::FaultException.new(
                        1, "Unavailable config format %s" % format
                    )
                end
                return CGI.escape(str)
            end
        end

        def local?
            if defined? @local and @local
                return true
            else
                return false
            end
        end
    end
end

# $Id$
