require 'puppet'
require 'puppet/sslcertificates'
require 'puppet/type'
require 'facter'
require 'openssl'
require 'puppet/transaction'
require 'puppet/transportable'
require 'puppet/metric'
require 'puppet/daemon'
require 'puppet/server'
require 'puppet/base64'

$noclientnetworking = false
begin
    require 'webrick'
    require 'cgi'
    require 'xmlrpc/client'
    require 'xmlrpc/server'
    require 'yaml'
rescue LoadError => detail
    $noclientnetworking = detail
    raise Puppet::Error, "You must have the Ruby XMLRPC, CGI, and Webrick libraries installed"
end

module Puppet
    class NetworkClientError < Puppet::Error; end
    class ClientError < Puppet::Error; end
    #---------------------------------------------------------------
    if $noclientnetworking
        Puppet.err "Could not load client network libs: %s" % $noclientnetworking
    else
        class NetworkClient < XMLRPC::Client
            attr_accessor :puppet_server, :puppet_port
            @clients = {}

            class << self
                include Puppet::Util
                include Puppet::Util::ClassGen
            end

            # Create a netclient for each handler
            def self.mkclients
                # add the methods associated with each namespace
                Puppet::Server::Handler.each { |handler|
                    interface = handler.interface
                    namespace = interface.prefix

                    # Create a subclass for every client type.  This is
                    # so that all of the methods are on their own class,
                    # so that they namespaces can define the same methods if
                    # they want.
                    constant = handler.to_s.sub(/^.+::/, '')
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
                            #Puppet.info "peer cert is %s" % @http.peer_cert
                            #Puppet.info "cert is %s" % @http.cert
                            begin
                                call("%s.%s" % [namespace, method.to_s],*args)
                            rescue OpenSSL::SSL::SSLError => detail
                                raise NetworkClientError,
                                    "Certificates were not trusted: %s" % detail
                            rescue XMLRPC::FaultException => detail
                                #Puppet.err "Could not call %s.%s: %s" %
                                #    [namespace, method, detail.faultString]
                                #raise NetworkClientError,
                                #    "XMLRPC Error: %s" % detail.faultString
                                raise NetworkClientError, detail.faultString
                            rescue Errno::ECONNREFUSED => detail
                                msg = "Could not connect to %s on port %s" %
                                    [@host, @port]
                                raise NetworkClientError, msg
                            rescue SocketError => detail
                                error = NetworkClientError.new(
                                    "Could not find server %s" % @puppetserver
                                )
                                error.set_backtrace detail.backtrace
                                raise error
                            rescue => detail
                                Puppet.err "Could not call %s.%s: %s" %
                                    [namespace, method, detail.inspect]
                                error = NetworkClientError.new(detail.to_s)
                                error.set_backtrace detail.backtrace
                                raise error
                            end
                        }
                    }
                }
            end

            def self.netclient(namespace)
                if @clients.empty?
                    self.mkclients()
                end

                namespace = symbolize(namespace)

                @clients[namespace]
            end

            def ca_file=(cafile)
                @http.ca_file = cafile
                store = OpenSSL::X509::Store.new
                store.add_file(cafile)
                store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
                @http.cert_store = store
            end

            def cert=(cert)
                #Puppet.debug "Adding certificate"
                @http.cert = cert
                @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            end

            def key=(key)
                @http.key = key
            end

            def initialize(hash)
                hash[:Path] ||= "/RPC2"
                hash[:Server] ||= "localhost"
                hash[:Port] ||= Puppet[:masterport]

                @puppet_server = hash[:Server]
                @puppet_port = hash[:Port]

                @puppetserver = hash[:Server]

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

                if hash[:Certificate]
                    self.cert = hash[:Certificate]
                else
                    unless defined? $nocertwarned
                        Puppet.err "No certificate; running with reduced functionality."
                        $nocertwarned = true
                    end
                end

                if hash[:Key]
                    self.key = hash[:Key]
                end

                if hash[:CAFile]
                    self.ca_file = hash[:CAFile]
                end

                # from here, i need to add the key, cert, and ca cert
                # and reorgize how i start the client
            end

            def local
                false
            end

            def local?
                false
            end
        end
    end
end

# $Id$
