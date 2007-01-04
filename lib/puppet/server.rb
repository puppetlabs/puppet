# the server
#
# allow things to connect to us and communicate, and stuff

require 'puppet'
require 'puppet/daemon'

$noservernetworking = false

begin
    require 'webrick'
    require 'webrick/https'
    require 'cgi'
    require 'xmlrpc/server'
    require 'xmlrpc/client'
rescue LoadError => detail
    $noservernetworking = detail
end

module Puppet
    class ServerError < RuntimeError; end
    #---------------------------------------------------------------
    if $noservernetworking
        Puppet.err "Could not create server: %s" % $noservernetworking
        class Server; end
    else
        class Server < WEBrick::HTTPServer
            include Puppet::Daemon

            Puppet.config.setdefaults(:puppetd,
                :listen => [false, "Whether puppetd should listen for
                    connections.  If this is true, then by default only the
                    ``runner`` server is started, which allows remote authorized
                    and authenticated nodes to connect and trigger ``puppetd``
                    runs."]
            )

            # Create our config object if necessary.  This works even if
            # there's no configuration file.
            def authconfig
                unless defined? @authconfig
                    @authconfig = Puppet::Server::AuthConfig.new()
                end

                @authconfig
            end
            
            # Read the CA cert and CRL and populate an OpenSSL::X509::Store
            # with them, with flags appropriate for checking client 
            # certificates for revocation
            def x509store
                if Puppet[:cacrl] == 'none'
                    # No CRL, no store needed
                    return nil
                end
                unless File.exist?(Puppet[:cacrl])
                    raise Puppet::Error, "Could not find CRL"
                end
                crl = OpenSSL::X509::CRL.new(File.read(Puppet[:cacrl]))
                store = OpenSSL::X509::Store.new
                store.purpose = OpenSSL::X509::PURPOSE_ANY
                store.flags = OpenSSL::X509::V_FLAG_CRL_CHECK_ALL|OpenSSL::X509::V_FLAG_CRL_CHECK
                store.add_file(@cacertfile)
                store.add_crl(crl)
                return store
            end

            def initialize(hash = {})
                Puppet.info "Starting server for Puppet version %s" % Puppet.version
                daemonize = nil
                if hash.include?(:Daemonize)
                    daemonize = hash[:Daemonize]
                end

                # FIXME we should have some kind of access control here, using
                # :RequestHandler
                hash[:Port] ||= Puppet[:masterport]
                hash[:Logger] ||= self.httplog
                hash[:AccessLog] ||= [
                    [ self.httplog, WEBrick::AccessLog::COMMON_LOG_FORMAT ],
                    [ self.httplog, WEBrick::AccessLog::REFERER_LOG_FORMAT ]
                ]

                if hash.include?(:Handlers)
                    unless hash[:Handlers].is_a?(Hash)
                        raise ServerError, "Handlers must have arguments"
                    end

                    @handlers = hash[:Handlers].collect { |handler, args|
                        hclass = nil
                        unless hclass = Handler.handler(handler)
                            raise ServerError, "Invalid handler %s" % handler
                        end
                        hclass.new(args)
                    }
                else
                    raise ServerError, "A server must have handlers"
                end

                # okay, i need to retrieve my cert and set it up, somehow
                # the default case will be that i'm also the ca
                if ca = @handlers.find { |handler| handler.is_a?(Puppet::Server::CA) }
                    @driver = ca
                    @secureinit = true
                    self.fqdn
                else
                    if hash.include?(:NoSecureInit)
                        @secureinit = false
                    else
                        @secureinit = true
                    end
                end

                unless self.readcert
                    unless self.requestcert
                        raise Puppet::Error, "Cannot start without certificates"
                    end
                end

                hash[:SSLCertificateStore] = x509store
                hash[:SSLCertificate] = @cert
                hash[:SSLPrivateKey] = @key
                hash[:SSLStartImmediately] = true
                hash[:SSLEnable] = true
                hash[:SSLCACertificateFile] = @cacertfile
                hash[:SSLVerifyClient] = OpenSSL::SSL::VERIFY_PEER
                hash[:SSLCertName] = nil

                super(hash)

                Puppet.info "Listening on port %s" % hash[:Port]

                # this creates a new servlet for every connection,
                # but all servlets have the same list of handlers
                # thus, the servlets can have their own state -- passing
                # around the requests and such -- but the handlers
                # have a global state

                # mount has to be called after the server is initialized
                self.mount("/RPC2", Puppet::Server::Servlet, @handlers)
            end

            # the base class for the different handlers
            class Handler
                attr_accessor :server
                class << self
                    include Puppet::Util
                end

                @subclasses = []

                def self.each
                    @subclasses.each { |c| yield c }
                end

                def self.handler(name)
                    name = name.to_s.downcase
                    @subclasses.find { |h|
                        h.name.to_s.downcase == name
                    }
                end

                def self.inherited(sub)
                    @subclasses << sub
                end

                def self.interface
                    if defined? @interface
                        return @interface
                    else
                        raise Puppet::DevError, "Handler %s has no defined interface" %
                            self
                    end
                end

                def self.name
                    unless defined? @name
                        @name = self.to_s.sub(/.+::/, '').intern
                    end

                    return @name
                end

                def initialize(hash = {})
                end
            end

            
            class ServerStatus < Handler

                @interface = XMLRPC::Service::Interface.new("status") { |iface|
                    iface.add_method("int status()")
                }

                @name = :Status

                def status(status = nil, client = nil, clientip = nil)
                    return 1
                end
            end

        end
    end

    #---------------------------------------------------------------
end

require 'puppet/server/authstore'
require 'puppet/server/authconfig'
require 'puppet/server/servlet'
require 'puppet/server/master'
require 'puppet/server/ca'
require 'puppet/server/fileserver'
require 'puppet/server/filebucket'
require 'puppet/server/pelement'
require 'puppet/server/runner'
require 'puppet/server/logger'
require 'puppet/server/report'
require 'puppet/client'

# $Id$
