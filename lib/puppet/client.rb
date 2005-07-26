#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'puppet'
require 'puppet/function'
require 'puppet/type'
#require 'puppet/fact'
require 'facter'
require 'puppet/transaction'
require 'puppet/transportable'
require 'puppet/metric'

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
            @@methods = [ :getconfig ]

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
                hash[:Port] ||= 8080
                super(hash[:Server],hash[:Path],hash[:Port])
            end
        end
    end

    class Client
        include Puppet
        attr_accessor :local
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
                    if $nonetworking
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
                self.config(objects)
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
                Puppet.err "Corrupt state file %s" % Puppet[:statefile]
                begin
                    File.unlink(Puppet[:statefile])
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
            #self.shutdown
        end

        #def callfunc(name,args)
        #    Puppet.debug("Calling callfunc on %s" % name)
        #    if function = Puppet::Function[name]
        #        #debug("calling function %s" % function)
        #        value = function.call(args)
        #        #debug("from %s got %s" % [name,value])
        #        return value
        #    else
        #        raise "Function '%s' not found" % name
        #    end
        #end

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
