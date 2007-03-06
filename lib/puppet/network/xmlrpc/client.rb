require 'puppet/sslcertificates'
require 'openssl'
require 'puppet/external/base64'

require 'xmlrpc/client'
require 'yaml'

module Puppet::Network
    class ClientError < Puppet::Error; end
    class XMLRPCClientError < Puppet::Error; end
    class XMLRPCClient < ::XMLRPC::Client
        attr_accessor :puppet_server, :puppet_port
        @clients = {}

        class << self
            include Puppet::Util
            include Puppet::Util::ClassGen
        end

        # Create a netclient for each handler
        def self.mkclient(handler)
            interface = handler.interface
            namespace = interface.prefix

            # Create a subclass for every client type.  This is
            # so that all of the methods are on their own class,
            # so that they namespaces can define the same methods if
            # they want.
            constant = handler.name.to_s.capitalize
            name = namespace.downcase
            newclient = genclass(name, :hash => @clients,
                :constant => constant)

            interface.methods.each { |ary|
                method = ary[0]
                if public_method_defined?(method)
                    raise Puppet::DevError, "Method %s is already defined" %
                        method
                end
                newclient.send(:define_method,method) { |*args|
                    Puppet.debug "Calling %s.%s" % [namespace, method]
                    begin
                        call("%s.%s" % [namespace, method.to_s],*args)
                    rescue OpenSSL::SSL::SSLError => detail
                        raise XMLRPCClientError,
                            "Certificates were not trusted: %s" % detail
                    rescue ::XMLRPC::FaultException => detail
                        #Puppet.err "Could not call %s.%s: %s" %
                        #    [namespace, method, detail.faultString]
                        #raise XMLRPCClientError,
                        #    "XMLRPC Error: %s" % detail.faultString
                        raise XMLRPCClientError, detail.faultString
                    rescue Errno::ECONNREFUSED => detail
                        msg = "Could not connect to %s on port %s" %
                            [@host, @port]
                        raise XMLRPCClientError, msg
                    rescue SocketError => detail
                        Puppet.err "Could not find server %s: %s" %
                            [@puppet_server, detail.to_s]
                        error = XMLRPCClientError.new(
                            "Could not find server %s" % @puppet_server
                        )
                        error.set_backtrace detail.backtrace
                        raise error
                    rescue => detail
                        Puppet.err "Could not call %s.%s: %s" %
                            [namespace, method, detail.inspect]
                        error = XMLRPCClientError.new(detail.to_s)
                        error.set_backtrace detail.backtrace
                        raise error
                    end
                }
            }

            return newclient
        end

        def self.handler_class(handler)
            @clients[handler] || self.mkclient(handler)
        end

        # Use cert information from a Puppet client to set up the http object.
        def cert_setup(client)
            unless FileTest.exists?(Puppet[:localcacert])
                raise Puppet::SSLCertificates::Support::MissingCertificate,
                    "Could not find ca certificate %s" % Puppet[:localcacert]
            end
            @http.ca_file = Puppet[:localcacert]
            store = OpenSSL::X509::Store.new
            store.add_file Puppet[:localcacert]
            store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
            @http.cert_store = store
            @http.cert = client.cert
            @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            @http.key = client.key
        end

        def initialize(hash = {})
            hash[:Path] ||= "/RPC2"
            hash[:Server] ||= Puppet[:server]
            hash[:Port] ||= Puppet[:masterport]

            @puppet_server = hash[:Server]
            @puppet_port = hash[:Port]

            super(
                hash[:Server],
                hash[:Path],
                hash[:Port],
                nil, # proxy_host
                nil, # proxy_port
                nil, # user
                nil, # password
                true, # use_ssl
                120 # a two minute timeout, instead of 30 seconds
            )
        end

        def local
            false
        end

        def local?
            false
        end
    end
end

# $Id$
