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
        @@http_cache = {}

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
                    rescue Errno::EPIPE
                        Puppet.warning "Other end went away; restarting connection and retrying"
                        self.recycle_connection(@cert_client)
                        retry
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
            # Cache it for next time
            @cert_client = client
            
            unless FileTest.exists?(Puppet[:localcacert])
                raise Puppet::SSLCertificates::Support::MissingCertificate,
                    "Could not find ca certificate %s" % Puppet[:localcacert]
            end

            # Pop open @http a little; older versions of Net::HTTP(s) didn't
            # give us a reader for ca_file... Grr...
            class << @http; attr_accessor :ca_file; end

            # Don't want to overwrite certificates, @http will freeze itself
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

            @puppet_server = hash[:Server]
            @puppet_port = hash[:Port]

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
            initialize_connection
        end
 
        def initialize_connection
            # Yes, this may well be redoing what the XMLRPC::Client constructor
            # did, but sometimes it won't be, because of the occasional retry.
            @http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port)
            @http.use_ssl = @use_ssl if @use_ssl
            @http.read_timeout = @timeout
            @http.open_timeout = @timeout

            # We overwrite the uninitialized @http here with a cached one.
            key = "%s:%s" % [@host, @port]

            # We overwrite the uninitialized @http here with a cached one.
            key = "%s%s" % [hash[:Server], hash[:Port]]
            if @@http_cache[key]
                @http = @@http_cache[key]
            else
                @@http_cache[key] = @http
            end
        end

        def recycle_connection(client)
            conn_key = "%s:%s" % [@host, @port]
            @@http_cache.delete(conn_key)
            
            initialize_connection
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
