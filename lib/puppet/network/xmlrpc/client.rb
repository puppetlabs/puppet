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
                newclient.send(:define_method,method) { |*args|
                    make_rpc_call(namespace, method, *args)
                }
            }

            return newclient
        end

        def self.handler_class(handler)
            @clients[handler] || self.mkclient(handler)
        end

        class ErrorHandler
            def initialize(&block)
                metaclass.define_method(:execute, &block)
            end
        end

        # Use a class variable so all subclasses have access to it.
        @@error_handlers = {}

        def self.error_handler(exception)
            if handler = @@error_handlers[exception.class]
                return handler
            else
                return @@error_handlers[:default]
            end
        end

        def self.handle_error(*exceptions, &block)
            handler = ErrorHandler.new(&block)

            exceptions.each do |exception|
                @@error_handlers[exception] = handler
            end
        end

        handle_error(OpenSSL::SSL::SSLError) do |client, detail, namespace, method|
            if detail.message =~ /bad write retry/
                Puppet.warning "Transient SSL write error; restarting connection and retrying"
                client.recycle_connection
                return :retry
            end
            ["certificate verify failed", "hostname was not match", "hostname not match"].each do |str|
                if detail.message.include?(str)
                    Puppet.warning "Certificate validation failed; consider using the certname configuration option"
                end
            end
            raise XMLRPCClientError, "Certificates were not trusted: %s" % detail
        end

        handle_error(:default) do |client, detail, namespace, method|
            if detail.message.to_s =~ /^Wrong size\. Was \d+, should be \d+$/
                Puppet.warning "XMLRPC returned wrong size.  Retrying."
                return :retry
            end
            Puppet.err "Could not call %s.%s: %s" % [namespace, method, detail.inspect]
            error = XMLRPCClientError.new(detail.to_s)
            error.set_backtrace detail.backtrace
            raise error
        end

        handle_error(OpenSSL::SSL::SSLError) do |client, detail, namespace, method|
            if detail.message =~ /bad write retry/
                Puppet.warning "Transient SSL write error; restarting connection and retrying"
                client.recycle_connection
                return :retry
            end
            ["certificate verify failed", "hostname was not match", "hostname not match"].each do |str|
                if detail.message.include?(str)
                    Puppet.warning "Certificate validation failed; consider using the certname configuration option"
                end
            end
            raise XMLRPCClientError, "Certificates were not trusted: %s" % detail
        end

        handle_error(::XMLRPC::FaultException) do |client, detail, namespace, method|
            raise XMLRPCClientError, detail.faultString
        end

        handle_error(Errno::ECONNREFUSED) do |client, detail, namespace, method|
            msg = "Could not connect to %s on port %s" % [client.host, client.port]
            raise XMLRPCClientError, msg
        end

        handle_error(SocketError) do |client, detail, namespace, method|
            Puppet.err "Could not find server %s: %s" % [@host, detail.to_s]
            error = XMLRPCClientError.new("Could not find server %s" % client.host)
            error.set_backtrace detail.backtrace
            raise error
        end

        handle_error(Errno::EPIPE, EOFError) do |client, detail, namespace, method|
            Puppet.info "Other end went away; restarting connection and retrying"
            client.recycle_connection
            return :retry
        end

        handle_error(Timeout::Error) do |client, detail, namespace, method|
            Puppet.err "Connection timeout calling %s.%s: %s" % [namespace, method, detail.to_s]
            error = XMLRPCClientError.new("Connection Timeout")
            error.set_backtrace(detail.backtrace)
            raise error
        end

        def make_rpc_call(namespace, method, *args)
            Puppet.debug "Calling %s.%s" % [namespace, method]
            begin
                call("%s.%s" % [namespace, method.to_s],*args)
            rescue SystemExit,NoMemoryError
                raise
            rescue Exception => detail
                retry if self.class.error_handler(detail).execute(self, detail, namespace, method) == :retry
            end
        ensure
            http.finish if http.started?
        end

        def http
            unless @http
                @http = Puppet::Network::HttpPool.http_instance(host, port, true)
            end
            @http
        end

        attr_reader :host, :port

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
                Puppet[:configtimeout] # use configured timeout (#1176)
            )
            @http = Puppet::Network::HttpPool.http_instance(@host, @port)
        end

        # Get rid of our existing connection, replacing it with a new one.
        # This should only happen if we lose our connection somehow (e.g., an EPIPE)
        # or we've just downloaded certs and we need to create new http instances
        # with the certs added.
        def recycle_connection
            if http.started?
                http.finish
            end
            @http = nil
            self.http # force a new one
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
