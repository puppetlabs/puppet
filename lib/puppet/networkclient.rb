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
    class NetworkClientError < RuntimeError; end
    class ClientError < RuntimeError; end
    #---------------------------------------------------------------
    if $noclientnetworking
        Puppet.err "Could not load client network libs: %s" % $noclientnetworking
    else
        class NetworkClient < XMLRPC::Client
            @clients = {}

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
                    newclient = Class.new(self)
                    @clients[namespace] = newclient

                    interface.methods.each { |ary|
                        method = ary[0]
                        Puppet.info "Defining %s.%s" % [namespace, method]
                        if public_method_defined?(method)
                            raise Puppet::DevError, "Method %s is already defined" %
                                method
                        end
                        newclient.send(:define_method,method) { |*args|
                            #Puppet.info "Calling %s" % method
                            #Puppet.info "peer cert is %s" % @http.peer_cert
                            #Puppet.info "cert is %s" % @http.cert
                            begin
                                call("%s.%s" % [namespace, method.to_s],*args)
                            rescue OpenSSL::SSL::SSLError => detail
                                raise NetworkClientError,
                                    "Certificates were not trusted"
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
                                Puppet.err "Could not find server %s" % @puppetserver
                                exit(12)
                            rescue => detail
                                Puppet.err "Could not call %s.%s: %s" %
                                    [namespace, method, detail.inspect]
                                #raise NetworkClientError.new(detail.to_s)
                                if Puppet[:debug]
                                    puts detail.backtrace
                                end
                                raise
                            end
                        }
                    }
                }
            end

            def self.netclient(namespace)
                if @clients.empty?
                    self.mkclients()
                end

                @clients[namespace]
            end

            def ca_file=(cafile)
                @http.ca_file = cafile
                store = OpenSSL::X509::Store.new
                cacert = OpenSSL::X509::Certificate.new(
                    File.read(cafile)
                )
                store.add_cert(cacert) 
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

                @puppetserver = hash[:Server]

                super(
                    hash[:Server],
                    hash[:Path],
                    hash[:Port],
                    nil, # proxy_host
                    nil, # proxy_port
                    nil, # user
                    nil, # password
                    true # use_ssl
                )

                if hash[:Certificate]
                    self.cert = hash[:Certificate]
                else
                    Puppet.err "No certificate; running with reduced functionality."
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
