# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'
require 'puppet/network/http_pool'
require 'puppet/util'

class Puppet::Agent
    require 'puppet/agent/fact_handler'
    require 'puppet/agent/plugin_handler'
    require 'puppet/agent/locker'

    include Puppet::Agent::FactHandler
    include Puppet::Agent::PluginHandler
    include Puppet::Agent::Locker

    # For benchmarking
    include Puppet::Util

    unless defined? @@sync
        @@sync = Sync.new
    end

    attr_accessor :catalog
    attr_reader :compile_time

    class << self
        # Puppetd should only have one instance running, and we need a way
        # to retrieve it.
        attr_accessor :instance
        include Puppet::Util
    end

    def clear
        @catalog.clear(true) if @catalog
        @catalog = nil
    end

    # Initialize and load storage
    def dostorage
        begin
            Puppet::Util::Storage.load
            @compile_time ||= Puppet::Util::Storage.cache(:configuration)[:compile_time]
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err "Corrupt state file %s: %s" % [Puppet[:statefile], detail]
            begin
                ::File.unlink(Puppet[:statefile])
                retry
            rescue => detail
                raise Puppet::Error.new("Cannot remove %s: %s" %
                    [Puppet[:statefile], detail])
            end
        end
    end
    
    # Just so we can specify that we are "the" instance.
    def initialize
        Puppet.settings.use(:main, :ssl, :puppetd)

        self.class.instance = self
        @running = false
        @splayed = false
    end

    # Prepare for catalog retrieval.  Downloads everything necessary, etc.
    def prepare
        dostorage()

        download_plugins()

        download_fact_plugins()

        upload_facts()
    end

    # Mark that we should restart.  The Puppet module checks whether we're running,
    # so this only gets called if we're in the middle of a run.
    def restart
        # If we're currently running, then just mark for later
        Puppet.notice "Received signal to restart; waiting until run is complete"
        @restart = true
    end

    # Should we restart?
    def restart?
        if defined? @restart
            @restart
        else
            false
        end
    end

    # Retrieve the cached config
    def retrievecache
        if FileTest.exists?(self.cachefile)
            return ::File.read(self.cachefile)
        else
            return nil
        end
    end

    # Get the remote catalog, yo.  Returns nil if no catalog can be found.
    def retrieve_catalog
        name = Facter.value("hostname")
        catalog_class = Puppet::Resource::Catalog

        # First try it with no cache, then with the cache.
        result = nil
        begin
            duration = thinmark do
                result = catalog_class.find(name, :use_cache => false)
            end
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Could not retrieve catalog from remote server: %s" % detail
        end

        unless result
            begin
                duration = thinmark do
                    result = catalog_class.find(name, :use_cache => true)
                end
            rescue => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not retrieve catalog from cache: %s" % detail
            end
        end

        return nil unless result

        convert_catalog(result, duration)
    end

    # Convert a plain resource catalog into our full host catalog.
    def convert_catalog(result, duration)
        catalog = result.to_ral
        catalog.retrieval_duration = duration
        catalog.host_config = true
        catalog.write_class_file
        return catalog
    end

    # The code that actually runs the catalog.  
    # This just passes any options on to the catalog,
    # which accepts :tags and :ignoreschedules.
    def run(options = {})
        got_lock = false
        splay
        Puppet::Util.sync(:puppetrun).synchronize(Sync::EX) do
            got_lock = lock do
                unless catalog = retrieve_catalog
                    Puppet.err "Could not retrieve catalog; skipping run"
                    return
                end

                begin
                    benchmark(:notice, "Finished catalog run") do
                        catalog.apply(options)
                    end
                rescue => detail
                    puts detail.backtrace if Puppet[:trace]
                    Puppet.err "Failed to apply catalog: %s" % detail
                end
            end

            unless got_lock
                Puppet.notice "Lock file %s exists; skipping catalog run" % lockfile.lockfile
                return
            end

            # Now close all of our existing http connections, since there's no
            # reason to leave them lying open.
            Puppet::Network::HttpPool.clear_http_instances
            
            lockfile.unlock

            # Did we get HUPped during the run?  If so, then restart now that we're
            # done with the run.
            Process.kill(:HUP, $$) if self.restart?
        end
    end

    def running?
        lockfile.locked?
    end

    private

    def self.timeout
        timeout = Puppet[:configtimeout]
        case timeout
        when String:
            if timeout =~ /^\d+$/
                timeout = Integer(timeout)
            else
                raise ArgumentError, "Configuration timeout must be an integer"
            end
        when Integer: # nothing
        else
            raise ArgumentError, "Configuration timeout must be an integer"
        end

        return timeout
    end

    # Actually retrieve the catalog, either from the server or from a
    # local master.
    def get_actual_config(facts)
        begin
            Timeout::timeout(self.class.timeout) do
                return get_remote_config(facts)
            end
        rescue Timeout::Error
            Puppet.err "Configuration retrieval timed out"
            return nil
        end
    end
    
    # Retrieve a config from a remote master.
    def get_remote_config(facts)
        textobjects = ""

        textfacts = CGI.escape(YAML.dump(facts))

        benchmark(:debug, "Retrieved catalog") do
            # error handling for this is done in the network client
            begin
                textobjects = @driver.getconfig(textfacts, Puppet[:catalog_format])
                begin
                    textobjects = CGI.unescape(textobjects)
                rescue => detail
                    raise Puppet::Error, "Could not CGI.unescape catalog"
                end

            rescue => detail
                Puppet.err "Could not retrieve catalog: %s" % detail
                return nil
            end
        end

        return nil if textobjects == ""

        @compile_time = Time.now
        Puppet::Util::Storage.cache(:configuration)[:facts] = facts
        Puppet::Util::Storage.cache(:configuration)[:compile_time] = @compile_time

        return textobjects
    end

    def splayed?
        @splayed
    end

    # Sleep when splay is enabled; else just return.
    def splay
        return unless Puppet[:splay]
        return if splayed?

        time = rand(Integer(Puppet[:splaylimit]) + 1)
        Puppet.info "Sleeping for %s seconds (splay is enabled)" % time
        sleep(time)
        @splayed = true
    end

    private

    def retrieve_and_apply_catalog(options)
        catalog = self.retrieve_catalog
        Puppet.notice "Starting catalog run"
        benchmark(:notice, "Finished catalog run") do
            catalog.apply(options)
        end
    end

    # Use our cached config, optionally specifying whether this is
    # necessary because of a failure.
    def use_cached_config(because_of_failure = false)
        return true if self.catalog

        if because_of_failure and ! Puppet[:usecacheonfailure]
            @catalog = nil
            Puppet.warning "Not using cache on failed catalog"
            return false
        end

        return false unless oldtext = self.retrievecache

        begin
            @catalog = YAML.load(oldtext).to_catalog
            @catalog.from_cache = true
            @catalog.host_config = true
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.warning "Could not load cached catalog: %s" % detail
            clear
            return false
        end
        return true
    end
end
