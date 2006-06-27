# the available clients

require 'puppet'
require 'puppet/networkclient'

module Puppet
    # FIXME this still isn't a good design, because none of the handlers overlap
    # so i could just as easily include them all in the main module
    # but at least it's better organized for now
    class Client
        include Puppet

        include Puppet::Util

        # FIXME The cert stuff should only come up with networking, so it
        # should be in the network client, not the normal client.  But if i do
        # that, it's hard to tell whether the certs have been initialized.
        include Puppet::Daemon
        attr_reader :secureinit
        attr_accessor :schedule, :lastrun, :local, :stopping

        class << self
            attr_reader :drivername, :handler
            attr_accessor :netclient
        end

        def initcerts
            unless self.readcert
                unless self.requestcert
                    return nil
                end
            end

            # unless we have a driver, we're a local client and we can't add
            # certs anyway, so it doesn't matter
            unless @driver
                return true
            end

            self.setcerts
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

            driverparam = self.class.drivername
            if hash.include?(:Server)
                if $noclientnetworking
                    raise NetworkClientError.new("Networking not available: %s" %
                        $nonetworking)
                end

                args = {:Server => hash[:Server]}
                args[:Port] = hash[:Port] || Puppet[:masterport]

                if self.readcert
                    args[:Certificate] = @cert
                    args[:Key] = @key
                    args[:CAFile] = @cacertfile
                end

                netclient = nil
                unless netclient = self.class.netclient
                    unless handler = self.class.handler
                        raise Puppet::DevError,
                            "Class %s has no handler defined" % self.class
                    end
                    namespace = self.class.handler.interface.prefix
                    netclient = Puppet::NetworkClient.netclient(namespace)
                    self.class.netclient = netclient
                end
                @driver = netclient.new(args)
                @local = false
            elsif hash.include?(driverparam)
                @driver = hash[driverparam]
                @local = true
            else
                raise ClientError, "%s must be passed a Server or %s" %
                    [self.class, driverparam]
            end
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
                if Puppet[:debug]
                    puts detail.backtrace
                end
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

        def setcerts
            @driver.cert = @cert
            @driver.key = @key
            @driver.ca_file = @cacertfile
        end

        def shutdown
            if self.stopping
                Puppet.notice "Already in shutdown"
            else
                self.stopping = true
                if self.respond_to? :running? and self.running?
                    Puppet::Storage.store
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
                if self.scheduled?
                    self.runnow
                end
            end

            # Run once before we start following the timer
            self.runnow
        end

        require 'puppet/client/proxy'
        require 'puppet/client/ca'
        require 'puppet/client/dipper'
        require 'puppet/client/file'
        require 'puppet/client/log'
        require 'puppet/client/master'
        require 'puppet/client/runner'
        require 'puppet/client/status'
        require 'puppet/client/pelement'
    end
end

# $Id$
