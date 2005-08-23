#!/usr/local/bin/ruby -w

# the available clients

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

$noclientnetworking = false
begin
    require 'webrick'
    require 'cgi'
    require 'xmlrpc/client'
    require 'xmlrpc/server'
rescue LoadError => detail
    $noclientnetworking = detail
end

module Puppet
    class NetworkClientError < RuntimeError; end
    class ClientError < RuntimeError; end
    #---------------------------------------------------------------
    if $noclientnetworking
        Puppet.err "Could not load client network libs: %s" % $noclientnetworking
    else
        class NetworkClient < XMLRPC::Client
            #include Puppet::Daemon

            # add the methods associated with each namespace
            Puppet::Server::Handler.each { |handler|
                interface = handler.interface
                namespace = interface.prefix

                interface.methods.each { |ary|
                    method = ary[0]
                    self.send(:define_method,method) { |*args|
                        #Puppet.info "peer cert is %s" % @http.peer_cert
                        #Puppet.info "cert is %s" % @http.cert
                        begin
                            call("%s.%s" % [namespace, method.to_s],*args)
                        rescue XMLRPC::FaultException => detail
                            Puppet.err "XML Could not call %s.%s: %s" %
                                [namespace, method, detail.faultString]
                            raise NetworkClientError,
                                "XMLRPC Error: %s" % detail.faultString
                        rescue => detail
                            Puppet.err "Could not call %s.%s: %s" %
                                [namespace, method, detail.inspect]
                            raise NetworkClientError.new(detail.to_s)
                        end
                    }
                }
            }

            [:key, :cert, :ca_file].each { |method|
                setmethod = method.to_s + "="
                #self.send(:define_method, method) {
                #    @http.send(method)
                #}
                self.send(:define_method, setmethod) { |*args|
                    Puppet.debug "Setting %s" % method 
                    @http.send(setmethod, *args)
                }
            }

            def initialize(hash)
                hash[:Path] ||= "/RPC2"
                hash[:Server] ||= "localhost"
                hash[:Port] ||= Puppet[:masterport]

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
                    Puppet.info "adding cert to @http"
                    @http.cert = hash[:Certificate]
                end

                if hash[:Key]
                    @http.key = hash[:Key]
                end

                if hash[:CAFile]
                    @http.ca_file = hash[:CAFile]
                    store = OpenSSL::X509::Store.new
                    cacert = OpenSSL::X509::Certificate.new(
                        File.read(hash[:CAFile])
                    )
                    store.add_cert(cacert) 
                    store.purpose = OpenSSL::X509::PURPOSE_SSL_CLIENT
                    @http.cert_store = store
                    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                end

                # from here, i need to add the key, cert, and ca cert
                # and reorgize how i start the client
            end
        end
    end

    class Client
        include Puppet
        include Puppet::Daemon
        attr_accessor :local, :secureinit

        def Client.facts
            facts = {}
            Facter.each { |name,fact|
                facts[name] = fact.downcase
            }

            facts
        end

        def initialize(hash)
            # to whom do we connect?
            @server = nil
            @nil = nil
            @secureinit = hash[:NoSecureInit] || true

            if hash.include?(:FQDN)
                @fqdn = hash[:FQDN]
            else
                self.fqdn
            end

            if hash.include?(:Cache)
                @cache = hash[:Cache]
            else
                @cache = true
            end

            if hash.include?(:Server)
                case hash[:Server]
                when String:
                    if $noclientnetworking
                        raise NetworkClientError.new("Networking not available: %s" %
                            $nonetworking)
                    end

                    args = {}
                    [:Port, :Server].each { |arg|
                        if hash.include?(:Port)
                            args[arg] = hash[arg]
                        end
                    }

                    if self.readcert
                        args[:Certificate] = @cert
                        args[:Key] = @key
                        args[:CAFile] = @cacertfile
                    end

                    @driver = Puppet::NetworkClient.new(args)
                    @local = false
                when Puppet::Server::Master:
                    @driver = hash[:Server]
                    @local = true
                else
                    raise ClientError.new("Server must be a hostname or a " +
                        "Puppet::Server::Master object")
                end
            else
                raise ClientError.new("Must pass :Server to client")
            end
        end

        def getconfig
            #client.loadproperty('files/sslclient.properties')
            Puppet.debug("getting config")

            facts = Client.facts

            unless facts.length > 0
                raise Puppet::ClientError.new(
                    "Could not retrieve any facts"
                )
            end

            objects = nil
            if @local
                objects = @driver.getconfig(facts)

                if objects == ""
                    raise Puppet::Error, "Could not retrieve configuration"
                end
            else
                textfacts = CGI.escape(Marshal::dump(facts))

                # error handling for this is done in the network client
                textobjects = @driver.getconfig(textfacts)

                unless textobjects == ""
                    begin
                        textobjects = CGI.unescape(textobjects)
                    rescue => detail
                        raise Puppet::Error, "Could not CGI.unescape configuration"
                    end
                end

                if @cache
                    if textobjects == ""
                        if FileTest.exists?(Puppet[:localconfig])
                            textobjects = File.read(Puppet[:localconfig])
                        else
                            raise Puppet::Error.new(
                                "Cannot connect to server and there is no cached configuration"
                            )
                        end
                    else
                        # we store the config so that if we can't connect next time, we
                        # can just run against the most recently acquired copy
                        confdir = File.dirname(Puppet[:localconfig])
                        unless FileTest.exists?(confdir)
                            Puppet.recmkdir(confdir, 0770)
                        end
                        File.open(Puppet[:localconfig], "w", 0660) { |f|
                            f.print textobjects
                        }
                    end
                elsif textobjects == ""
                    raise Puppet::Error, "Could not retrieve configuration"
                end

                begin
                    objects = Marshal::load(textobjects)
                rescue => detail
                    raise Puppet::Error.new("Could not understand configuration")
                end
            end
            if objects.is_a?(Puppet::TransBucket)
                @objects = objects
            else
                Puppet.warning objects.inspect
                raise NetworkClientError.new(objects.class)
            end
        end

        # this method is how the client receives the tree of Transportable
        # objects
        # for now, just descend into the tree and perform and necessary
        # manipulations
        def config
            unless defined? @objects
                raise Puppet::Error, "Cannot config; objects not defined"
            end
            Puppet.debug("Calling config")

            # XXX this is kind of a problem; if the user changes the state file
            # after this, then we have to reload the file and everything...
            begin
                Puppet::Storage.init
                Puppet::Storage.load
            rescue => detail
                Puppet.err "Corrupt state file %s" % Puppet[:checksumfile]
                begin
                    File.unlink(Puppet[:checksumfile])
                    retry
                rescue => detail
                    raise Puppet::Error.new("Cannot remove %s: %s" %
                        [Puppet[statefile], detail])
                end
            end

            container = @objects.to_type
            #if @local
            #    container = @objects.to_type
            #else
            #    container = Marshal::load(@objects).to_type
            #end

            # this is a gross hack... but i don't see a good way around it
            # set all of the variables to empty
            Puppet::Transaction.init

            # for now we just evaluate the top-level container, but eventually
            # there will be schedules and such associated with each object,
            # and probably with the container itself
            transaction = container.evaluate
            #transaction = Puppet::Transaction.new(objects)
            transaction.toplevel = true
            transaction.evaluate
            Puppet::Metric.gather
            Puppet::Metric.tally
            if Puppet[:rrdgraph] == true
                Metric.store
                Metric.graph
            end
            Puppet::Storage.store

            return transaction
            #self.shutdown
        end

        def initcerts
            unless self.readcert
                unless self.requestcert
                    return nil
                end
            end

            unless @driver
                return true
            end

            Puppet.info "setting cert and key and such"
            @driver.cert = @cert
            @driver.key = @key
            @driver.ca_file = @cacertfile
        end
    end
    #---------------------------------------------------------------
end

# $Id$
