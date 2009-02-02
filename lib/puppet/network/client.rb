# the available clients

require 'puppet'
require 'puppet/network/xmlrpc/client'
require 'puppet/util/subclass_loader'
require 'puppet/util/methodhelper'
require 'puppet/sslcertificates/support'

require 'puppet/network/handler'

require 'net/http'

# Some versions of ruby don't have this method defined, which basically causes
# us to never use ssl.  Yay.
class Net::HTTP
    def use_ssl?
        if defined? @use_ssl
            @use_ssl
        else
            false
        end
    end

    # JJM: This is a "backport" of sorts to older ruby versions which
    # do not have this accessor.  See #896 for more information.
    unless Net::HTTP.instance_methods.include? "enable_post_connection_check"
        attr_accessor :enable_post_connection_check
    end
end

# The base class for all of the clients.  Many clients just directly
# call methods, but some of them need to do some extra work or
# provide a different interface.
class Puppet::Network::Client
    Client = self
    include Puppet::Util
    extend Puppet::Util::SubclassLoader
    include Puppet::Util::MethodHelper

    # This handles reading in the key and such-like.
    include Puppet::SSLCertificates::Support

    attr_accessor :schedule, :lastrun, :local, :stopping

    attr_reader :driver

    # Set up subclass loading
    handle_subclasses :client, "puppet/network/client"

    # Determine what clients look for when being passed an object for local
    # client/server stuff.  E.g., you could call Client::CA.new(:CA => ca).
    def self.drivername
        unless defined? @drivername
            @drivername = self.name
        end
        @drivername
    end

    # Figure out the handler for our client.
    def self.handler
        unless defined? @handler
            @handler = Puppet::Network::Handler.handler(self.name)
        end
        @handler
    end

    # The class that handles xmlrpc interaction for us.
    def self.xmlrpc_client
        unless defined? @xmlrpc_client
            @xmlrpc_client = Puppet::Network::XMLRPCClient.handler_class(self.handler)
        end
        @xmlrpc_client
    end

    # Create our client.
    def initialize(hash)
        # to whom do we connect?
        @server = nil

        if hash.include?(:Cache)
            @cache = hash[:Cache]
        else
            @cache = true
        end

        driverparam = self.class.drivername
        if hash.include?(:Server)
            args = {:Server => hash[:Server]}
            @server = hash[:Server]
            args[:Port] = hash[:Port] || Puppet[:masterport]

            @driver = self.class.xmlrpc_client.new(args)

            self.read_cert

            # We have to start the HTTP connection manually before we start
            # sending it requests or keep-alive won't work.  Note that with #1010,
            # we don't currently actually want keep-alive.
            @driver.start if @driver.respond_to? :start and Puppet::Network::HttpPool.keep_alive?

            @local = false
        elsif hash.include?(driverparam)
            @driver = hash[driverparam]
            if @driver == true
                @driver = self.class.handler.new
            end
            @local = true
        else
            raise Puppet::Network::ClientError, "%s must be passed a Server or %s" % [self.class, driverparam]
        end
    end

    # Are we a local client?
    def local?
        if defined? @local and @local
            true
        else
            false
        end
    end

    # Make sure we set the driver up when we read the cert in.
    def recycle_connection
        @driver.recycle_connection if @driver.respond_to?(:recycle_connection)
    end

    # A wrapper method to run and then store the last run time
    def runnow
        if self.stopping
            Puppet.notice "In shutdown progress; skipping run"
            return
        end
        begin
            self.run
            self.lastrun = Time.now.to_i
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Could not run %s: %s" % [self.class, detail]
        end
    end

    def run
        raise Puppet::DevError, "Client type %s did not override run" %
            self.class
    end

    def scheduled?
        if sched = self.schedule
            return sched.match?(self.lastrun)
        else
            return true
        end
    end

    def shutdown
        if self.stopping
            Puppet.notice "Already in shutdown"
        else
            self.stopping = true
            if self.respond_to? :running? and self.running?
                Puppet::Util::Storage.store
            end
            rmpidfile()
        end
    end

    # Start listening for events.  We're pretty much just listening for
    # timer events here.
    def start
        # Create our timer.  Puppet will handle observing it and such.
        timer = Puppet.newtimer(
            :interval => Puppet[:runinterval],
            :tolerance => 1,
            :start? => true
        ) do
            begin
                self.runnow if self.scheduled?
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not run client; got otherwise uncaught exception: %s" % detail
            end
        end

        # Run once before we start following the timer
        self.runnow
    end

    require 'puppet/network/client/proxy'
end

