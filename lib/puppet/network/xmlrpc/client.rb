require 'puppet/sslcertificates'
require 'puppet/network/http_pool'
require 'openssl'
require 'puppet/external/base64'

require 'xmlrpc/client'
require 'net/https'
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
            # so that their namespaces can define the same methods if
            # they want.
            constant = handler.name.to_s.capitalize
            name = namespace.downcase
            newclient = genclass(name, :hash => @clients, :constant => constant)

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
                        if detail.message =~ /bad write retry/
                            Puppet.warning "Transient SSL write error; restarting connection and retrying"
                            self.recycle_connection
                            retry
                        end
                        ["certificate verify failed", "hostname was not match", "hostname not match"].each do |str|
                            if detail.message.include?(str)
                                Puppet.warning "Certificate validation failed; considering using the certname configuration option"
                            end
                        end 
                        raise XMLRPCClientError,
                            "Certificates were not trusted: %s" % detail
                    rescue ::XMLRPC::FaultException => detail
                        raise XMLRPCClientError, detail.faultString
                    rescue Errno::ECONNREFUSED => detail
                        msg = "Could not connect to %s on port %s" %
                            [@host, @port]
                        raise XMLRPCClientError, msg
                    rescue SocketError => detail
                        Puppet.err "Could not find server %s: %s" %
                            [@host, detail.to_s]
                        error = XMLRPCClientError.new(
                            "Could not find server %s" % @host
                        )
                        error.set_backtrace detail.backtrace
                        raise error
                    rescue Errno::EPIPE, EOFError
                        Puppet.warning "Other end went away; restarting connection and retrying"
                        self.recycle_connection
                        retry
                    rescue => detail
                        if detail.message =~ /^Wrong size\. Was \d+, should be \d+$/
                            Puppet.warning "XMLRPC returned wrong size.  Retrying."
                            retry
                        end    
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

        def http
            unless @http
                @http = Puppet::Network::HttpPool.http_instance(@host, @port, true)
            end
            @http
        end

        def initialize(hash = {})
            hash[:Path] ||= "/RPC2"
            hash[:Server] ||= Puppet[:server]
            hash[:Port] ||= Puppet[:masterport]
            hash[:HTTPProxyHost] ||= Puppet[:http_proxy_host]
            hash[:HTTPProxyPort] ||= Puppet[:http_proxy_port]

            if "none" == hash[:HTTPProxyHost]
                hash[:HTTPProxyHost] = nil
                hash[:HTTPProxyPort] = nil
            end

            super(
                hash[:Server],
                hash[:Path],
                hash[:Port],
                hash[:HTTPProxyHost],
                hash[:HTTPProxyPort],
                nil, # user
                nil, # password
                true, # use_ssl
                120 # a two minute timeout, instead of 30 seconds
            )
            @http = Puppet::Network::HttpPool.http_instance(@host, @port)
        end
 
        # Get rid of our existing connection, replacing it with a new one.
        # This should only happen if we lose our connection somehow (e.g., an EPIPE)
        # or we've just downloaded certs and we need to create new http instances
        # with the certs added.
        def recycle_connection
            @http = Puppet::Network::HttpPool.http_instance(@host, @port, true) # reset the instance
        end
        
        def start
            begin
                @http.start unless @http.started?
            rescue => detail
                Puppet.err "Could not connect to server: %s" % detail
            end
        end

        def local
            false
        end

        def local?
            false
        end
    end
end
