# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'
require 'puppet/network/http_pool'
require 'puppet/util'

class Puppet::Configurer
    class CommandHookError < RuntimeError; end

    require 'puppet/configurer/fact_handler'
    require 'puppet/configurer/plugin_handler'

    include Puppet::Configurer::FactHandler
    include Puppet::Configurer::PluginHandler

    # For benchmarking
    include Puppet::Util

    attr_accessor :catalog
    attr_reader :compile_time

    # Provide more helpful strings to the logging that the Agent does
    def self.to_s
        "Puppet configuration client"
    end

    class << self
        # Puppetd should only have one instance running, and we need a way
        # to retrieve it.
        attr_accessor :instance
        include Puppet::Util
    end

    # How to lock instances of this class.
    def self.lockfile_path
        Puppet[:puppetdlockfile]
    end

    def clear
        @catalog.clear(true) if @catalog
        @catalog = nil
    end

    def execute_postrun_command
        execute_from_setting(:postrun_command)
    end

    def execute_prerun_command
        execute_from_setting(:prerun_command)
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

        execute_prerun_command
    end

    # Get the remote catalog, yo.  Returns nil if no catalog can be found.
    def retrieve_catalog
        if Puppet::Resource::Catalog.indirection.terminus_class == :rest
            # This is a bit complicated.  We need the serialized and escaped facts,
            # and we need to know which format they're encoded in.  Thus, we
            # get a hash with both of these pieces of information.
            fact_options = facts_for_uploading()
        else
            fact_options = {}
        end

        # First try it with no cache, then with the cache.
        unless (Puppet[:use_cached_catalog] and result = retrieve_catalog_from_cache(fact_options)) or result = retrieve_new_catalog(fact_options)
            if ! Puppet[:usecacheonfailure]
                Puppet.warning "Not using cache on failed catalog"
                return nil
            end
            result = retrieve_catalog_from_cache(fact_options)
        end

        return nil unless result

        convert_catalog(result, @duration)
    end

    # Convert a plain resource catalog into our full host catalog.
    def convert_catalog(result, duration)
        catalog = result.to_ral
        catalog.finalize
        catalog.retrieval_duration = duration
        catalog.host_config = true
        catalog.write_class_file
        return catalog
    end

    # The code that actually runs the catalog.
    # This just passes any options on to the catalog,
    # which accepts :tags and :ignoreschedules.
    def run(options = {})
        begin
            prepare()
        rescue SystemExit,NoMemoryError
            raise
        rescue Exception => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Failed to prepare catalog: %s" % detail
        end

        if catalog = options[:catalog]
            options.delete(:catalog)
        elsif ! catalog = retrieve_catalog
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

        # Now close all of our existing http connections, since there's no
        # reason to leave them lying open.
        Puppet::Network::HttpPool.clear_http_instances
    ensure
        execute_postrun_command
    end

    private

    def self.timeout
        timeout = Puppet[:configtimeout]
        case timeout
        when String
            if timeout =~ /^\d+$/
                timeout = Integer(timeout)
            else
                raise ArgumentError, "Configuration timeout must be an integer"
            end
        when Integer # nothing
        else
            raise ArgumentError, "Configuration timeout must be an integer"
        end

        return timeout
    end

    def execute_from_setting(setting)
        return if (command = Puppet[setting]) == ""

        begin
            Puppet::Util.execute([command])
        rescue => detail
            raise CommandHookError, "Could not run command from #{setting}: #{detail}"
        end
    end

    def retrieve_catalog_from_cache(fact_options)
        result = nil
        @duration = thinmark do
            result = Puppet::Resource::Catalog.find(Puppet[:certname], fact_options.merge(:ignore_terminus => true))
        end
        Puppet.notice "Using cached catalog"
        result
    rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not retrieve catalog from cache: %s" % detail
        return nil
    end

    def retrieve_new_catalog(fact_options)
        result = nil
        @duration = thinmark do
            result = Puppet::Resource::Catalog.find(Puppet[:certname], fact_options.merge(:ignore_cache => true))
        end
        result
    rescue SystemExit,NoMemoryError
        raise
    rescue Exception => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Could not retrieve catalog from remote server: %s" % detail
        return nil
    end
end
