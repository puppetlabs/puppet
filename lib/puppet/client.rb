#!/usr/local/bin/ruby -w

# $Id$

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
            include Puppet::Daemon

            @@methods = [ :getconfig, :getcert ]

            @@methods.each { |method|
                self.send(:define_method,method) { |*args|
                    begin
                        call("puppetmaster.%s" % method.to_s,*args)
                    rescue => detail
                        raise NetworkClientError.new(detail)
                    end
                }
            }

            def initialize(hash)
                hash[:Path] ||= "/RPC2"
                hash[:Server] ||= "localhost"
                hash[:Port] ||= Puppet[:masterport]
                super(hash[:Server],hash[:Path],hash[:Port])
            end
        end
    end

    class Client
        include Puppet
        attr_accessor :local, :secureinit
        attr_reader :fqdn

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
                    @driver = Puppet::NetworkClient.new(args)
                    @local = false
                when Puppet::Master:
                    @driver = hash[:Server]
                    @local = true
                else
                    raise ClientError.new("Server must be a hostname or a " +
                        "Puppet::Master object")
                end
            else
                raise ClientError.new("Must pass :Server to client")
            end

            if hash.include?(:FQDN)
                @fqdn = hash[:FQDN]
            else
                hostname = Facter["hostname"].value
                domain = Facter["domain"].value
                @fqdn = [hostname, domain].join(".")
            end

            @secureinit = hash[:NoSecureInit] || true
        end

        def initcerts
            return unless @secureinit
            # verify we've got all of the certs set up and such

            # we are not going to encrypt our key, but we need at a minimum
            # a keyfile and a certfile
            certfile = File.join(Puppet[:certdir], [@fqdn, "pem"].join("."))
            keyfile = File.join(Puppet[:privatekeydir], [@fqdn, "pem"].join("."))
            publickeyfile = File.join(Puppet[:publickeydir], [@fqdn, "pem"].join("."))

            [Puppet[:certdir], Puppet[:privatekeydir], Puppet[:csrdir],
                Puppet[:publickeydir]].each { |dir|
                unless FileTest.exists?(dir)
                    Puppet.recmkdir(dir, 0770)
                end
            }

            inited = false
            if File.exists?(keyfile)
                # load the key
                @key = OpenSSL::PKey::RSA.new(File.read(keyfile))
            else
                # create a new one and store it
                Puppet.info "Creating a new SSL key at %s" % keyfile
                @key = OpenSSL::PKey::RSA.new(Puppet[:keylength])
                File.open(keyfile, "w", 0660) { |f| f.print @key.to_pem }
                File.open(publickeyfile, "w", 0660) { |f|
                    f.print @key.public_key.to_pem
                }
            end

            unless File.exists?(certfile)
                Puppet.info "Creating a new certificate request for %s" % @fqdn
                name = OpenSSL::X509::Name.new([["CN", @fqdn]])

                @csr = OpenSSL::X509::Request.new
                @csr.version = 0
                @csr.subject = name
                @csr.public_key = @key.public_key
                @csr.sign(@key, OpenSSL::Digest::MD5.new)

                Puppet.info "Requesting certificate"

                cert = @driver.getcert(@csr.to_pem)

                if cert.nil?
                    raise Puppet::Error, "Failed to get certificate"
                end
                File.open(certfile, "w", 0660) { |f| f.print cert }
                begin
                    @cert = OpenSSL::X509::Certificate.new(cert)
                    inited = true
                rescue => detail
                    raise Puppet::Error.new(
                        "Invalid certificate: %s" % detail
                    )
                end
            end

            return inited
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
            else
                textfacts = CGI.escape(Marshal::dump(facts))
                textobjects = CGI.unescape(@driver.getconfig(textfacts))
                begin
                    objects = Marshal::load(textobjects)
                rescue => detail
                    raise Puppet::Error.new("Could not understand configuration")
                end
            end
            if objects.is_a?(Puppet::TransBucket)
                return self.config(objects)
            else
                Puppet.warning objects.inspect
                raise NetworkClientError.new(objects.class)
            end
        end

        # this method is how the client receives the tree of Transportable
        # objects
        # for now, just descend into the tree and perform and necessary
        # manipulations
        def config(tree)
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

            container = tree.to_type
            #if @local
            #    container = tree.to_type
            #else
            #    container = Marshal::load(tree).to_type
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

        private

        #def on_init
        #    @default_namespace = 'urn:puppet-client'
        #    add_method(self, 'config', 'config')
        #    add_method(self, 'callfunc', 'name', 'arguments')
        #end

        def cert(filename)
            OpenSSL::X509::Certificate.new(File.open(File.join(@dir, filename)) { |f|
                f.read
            })
        end

        def key(filename)
            OpenSSL::PKey::RSA.new(File.open(File.join(@dir, filename)) { |f|
                f.read
            })
        end

    end
    #---------------------------------------------------------------
end
