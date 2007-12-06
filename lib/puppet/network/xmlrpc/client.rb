require 'puppet/sslcertificates'
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
        @@http_cache = {}

        class << self
            include Puppet::Util
            include Puppet::Util::ClassGen
        end

        # Clear our http cache.
        def self.clear_http_instances
            @@http_cache.clear
        end

        # Retrieve a cached http instance of caching is enabled, else return
        # a new one.
        def self.http_instance(host, port, reset = false)
            # We overwrite the uninitialized @http here with a cached one.
            key = "%s:%s" % [host, port]

            # Return our cached instance if keepalive is enabled and we've got
            # a cache, as long as we're not resetting the instance.
            return @@http_cache[key] if ! reset and Puppet[:http_keepalive] and @@http_cache[key]

            args = [host, port]
            if Puppet[:http_proxy_host] == "none"
                args << nil << nil
            else
                args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
            end
            @http = Net::HTTP.new(*args)

            # Pop open @http a little; older versions of Net::HTTP(s) didn't
            # give us a reader for ca_file... Grr...
            class << @http; attr_accessor :ca_file; end

            @http.use_ssl = true
            @http.read_timeout = 120
            @http.open_timeout = 120
            # JJM Configurable fix for #896.
            if Puppet[:http_enable_post_connection_check]
                @http.enable_post_connection_check = true
            else
                @http.enable_post_connection_check = false
            end

            @@http_cache[key] = @http if Puppet[:http_keepalive]

            return @http
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
                        if detail.message =~ /bad write retry/
                            Puppet.warning "Transient SSL write error; restarting connection and retrying"
                            self.recycle_connection(@cert_client)
                            retry
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
                        self.recycle_connection(@cert_client)
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

        # Use cert information from a Puppet client to set up the http object.
        def cert_setup(client)
            # Cache it for next time
            @cert_client = client
            
            unless FileTest.exist?(Puppet[:localcacert])
                raise Puppet::SSLCertificates::Support::MissingCertificate,
                    "Could not find ca certificate %s" % Puppet[:localcacert]
            end

            # We can't overwrite certificates, @http will freeze itself
            # once started.
            unless @http.ca_file
                @http.ca_file = Puppet[:localcacert]
                store = OpenSSL::X509::Store.new
                store.add_file Puppet[:localcacert]
                store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
                @http.cert_store = store
                @http.cert = client.cert
                @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
                @http.key = client.key
            end
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
            @http = self.class.http_instance(@host, @port)
        end
 
        def recycle_connection(client)
            @http = self.class.http_instance(@host, @port, true) # reset the instance

            cert_setup(client)
        end
        
        def start
            @http.start unless @http.started?
        end

        def local
            false
        end

        def local?
            false
        end
    end
end
