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
                end

                unless self.readcert
                    unless self.requestcert
                        raise Puppet::Error, "Cannot start without certificates"
                    end
                end

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
        end

        class Server
            # the base class for the different handlers
            class Handler
                attr_accessor :server
                @subclasses = []

                def self.each
                    @subclasses.each { |c| yield c }
                end

                def self.handler(name)
                    @subclasses.find { |h|
                        h.name == name
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
require 'puppet/server/servlet'
require 'puppet/server/master'
require 'puppet/server/ca'
require 'puppet/server/fileserver'
require 'puppet/server/filebucket'
require 'puppet/server/logger'
require 'puppet/client'

# $Id$
