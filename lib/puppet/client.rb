#!/usr/local/bin/ruby -w

# $Id$

# the available clients

require 'puppet'
require 'puppet/function'
require 'puppet/type'
require 'puppet/fact'
require 'puppet/transaction'
require 'puppet/transportable'
require 'puppet/metric'
require 'http-access2'
require 'soap/rpc/driver'
require 'soap/rpc/httpserver'
#require 'webrick/https'
require 'logger'

module Puppet
    class ClientError < RuntimeError; end
    #---------------------------------------------------------------
    class Client < SOAP::RPC::HTTPServer
        def initialize(hash)
            # to whom do we connect?
            @server = nil
            @nil = nil
            @url = hash[:Server]
            if hash.include?(:Listen) and hash[:Listen] == false
                Puppet.debug "We're a local client"
                @localonly = true
                @driver = @url
            else
                Puppet.debug "We're a networked client"
                @localonly = false
                @driver = SOAP::RPC::Driver.new(@url, 'urn:puppet-server')
                @driver.add_method("getconfig", "name")
            end
            unless @localonly
                hash.delete(:Server)

                Puppet.debug "Server is %s" % @url

                hash[:BindAddress] ||= "0.0.0.0"
                hash[:Port] ||= 17444
                #hash[:Debug] ||= true
                hash[:AccessLog] ||= []

                super(hash)
            end
        end

        def getconfig
            Puppet.debug "server is %s" % @url
            #client.loadproperty('files/sslclient.properties')
            Puppet.debug("getting config")
            objects = nil
            if @localonly
                objects = @driver.getconfig(self)
            else
                objects = @driver.getconfig(Puppet::Fact["hostname"])
            end
            self.config(objects)
        end

        # this method is how the client receives the tree of Transportable
        # objects
        # for now, just descend into the tree and perform and necessary
        # manipulations
        def config(tree)
            Puppet.debug("Calling config")
            container = Marshal::load(tree).to_type

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
            self.shutdown
        end

        def callfunc(name,args)
            Puppet.debug("Calling callfunc on %s" % name)
            if function = Puppet::Function[name]
                #Puppet.debug("calling function %s" % function)
                value = function.call(args)
                #Puppet.debug("from %s got %s" % [name,value])
                return value
            else
                raise "Function '%s' not found" % name
            end
        end

        private

        def on_init
            @default_namespace = 'urn:puppet-client'
            add_method(self, 'config', 'config')
            add_method(self, 'callfunc', 'name', 'arguments')
        end

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
