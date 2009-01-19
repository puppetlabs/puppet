# The class that functions as our client agent.  It has all
# of the logic for downloading and applying catalogs, and anything
# else needed by puppetd to do its job.
class Puppet::Agent
    # The 'require' is inside the class so the Agent constant already exists.
    require 'puppet/agent/downloader'

    # Disable all agent activity.  This would be used by someone to
    # temporarily stop puppetd without killing the daemon.
    def self.disable
        lockfile.lock :anonymous => true
    end

    # Enable activity again.
    def self.enable
        lockfile.unlock :anonymous => true
    end

    def self.enabled?
        ! lockfile.locked?
    end

    # The lockfile we're using.
    def self.lockfile
        unless defined?(@lockfile) and @lockfile
            @lockfile = Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile])
        end

        @lockfile
    end

    # Determine the timeout value to use.
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

    # storage

    # config timeout

    # setclasses

    # Retrieve our catalog, possibly from the cache.
    def download_catalog
        unless c = Puppet::Resource::Catalog.find(name, :use_cache => (!Puppet[:ignorecache]))
            raise "Could not retrieve catalog"
        end
        c.host_config = true
        c
    end

    # Should we be downloading plugins?
    def download_plugins?
        Puppet[:pluginsync]
    end

    # Download, and load if necessary, central plugins.
    def download_plugins
        Puppet::Agent::Downloader.new("plugin", Puppet[:pluginsource], Puppet[:plugindest], Puppet[:pluginsignore]).evaluate
    end

    # Should we be downloading facts?
    def download_facts?
        Puppet[:factsync]
    end

    # Download, and load if necessary, central facts.
    def download_facts
        Puppet::Agent::Downloader.new("fact", Puppet[:factsource], Puppet[:factdest], Puppet[:factsignore]).evaluate
    end

    def initialize(options = {})
        options.each do |param, value|
            if respond_to?(param.to_s + "=")
                send(param.to_s + "=", value)
            else
                raise ArgumentError, "%s is not a valid option for Agents" % param
            end
        end
    end

    def name
        Puppet[:certname]
    end

    # Is this a onetime agent?
    attr_accessor :onetime
    def onetime?
        onetime
    end

    def run
        splay() if splay?

        download_plugins() if download_plugins?

        download_facts() if download_facts?

        upload_facts()

        catalog = download_catalog()

        apply(catalog)
    end

    # Should we splay?
    def splay?
        Puppet[:splay]
    end

    # Sleep for a random but consistent period of time if configured to
    # do so.
    def splay
        return unless Puppet[:splay]
        return if splayed?

        time = rand(Integer(Puppet[:splaylimit]) + 1)
        Puppet.info "Sleeping for %s seconds (splay is enabled)" % time
        sleep(time)
        @splayed = true
    end

    # Have we already splayed?
    def splayed?
        defined?(@splayed) and @splayed
    end

    def start
    end

    # This works because puppetd configures Facts to use 'facter' for
    # finding facts and the 'rest' terminus for caching them.  Thus, we'll
    # compile them and then "cache" them on the server.
    def upload_facts
        Puppet::Node::Facts.find(Puppet[:certname])
    end
end

class OldMaster
    attr_accessor :catalog
    attr_reader :compile_time

    class << self
        # Puppetd should only have one instance running, and we need a way
        # to retrieve it.
        attr_accessor :instance
        include Puppet::Util
    end

    def self.facts
        
        down = Puppet[:downcasefacts]

        Facter.clear

        # Reload everything.
        if Facter.respond_to? :loadfacts
            Facter.loadfacts
        elsif Facter.respond_to? :load
            Facter.load
        else
            Puppet.warning "You should upgrade your version of Facter to at least 1.3.8"
        end

        # This loads all existing facts and any new ones.  We have to remove and
        # reload because there's no way to unload specific facts.
        loadfacts()
        facts = Facter.to_hash.inject({}) do |newhash, array|
            name, fact = array
            if down
                newhash[name] = fact.to_s.downcase
            else
                newhash[name] = fact.to_s
            end
            newhash
        end
 
        facts
    end

    # Retrieve the config from a remote server.  If this fails, then
    # use the cached copy.
    def getconfig
        dostorage()

        facts = nil
        Puppet::Util.benchmark(:debug, "Retrieved facts") do
            facts = self.class.facts
        end

        raise Puppet::Network::ClientError.new("Could not retrieve any facts") unless facts.length > 0

        Puppet.debug("Retrieving catalog")

        # If we can't retrieve the catalog, just return, which will either
        # fail, or use the in-memory catalog.
        unless marshalled_objects = get_actual_config(facts)
            use_cached_config(true)
            return
        end

        begin
            case Puppet[:catalog_format]
            when "marshal": objects = Marshal.load(marshalled_objects)
            when "yaml": objects = YAML.load(marshalled_objects)
            else
                raise "Invalid catalog format '%s'" % Puppet[:catalog_format]
            end
        rescue => detail
            msg = "Configuration could not be translated from %s" % Puppet[:catalog_format]
            msg += "; using cached catalog" if use_cached_config(true)
            Puppet.warning msg
            return
        end

        self.setclasses(objects.classes)

        # Clear all existing objects, so we can recreate our stack.
        clear() if self.catalog

        # Now convert the objects to a puppet catalog graph.
        begin
            @catalog = objects.to_catalog
        rescue => detail
            clear()
            puts detail.backtrace if Puppet[:trace]
            msg = "Configuration could not be instantiated: %s" % detail
            msg += "; using cached catalog" if use_cached_config(true)
            Puppet.warning msg
            return
        end

        # Keep the state database up to date.
        @catalog.host_config = true
    end
    
    # Just so we can specify that we are "the" instance.
    def initialize(*args)
        Puppet.settings.use(:main, :ssl, :puppetd)
        super

        self.class.instance = self
        @running = false
        @splayed = false
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

    # The code that actually runs the catalog.  
    # This just passes any options on to the catalog,
    # which accepts :tags and :ignoreschedules.
    def run(options = {})
        got_lock = false
        splay
        Puppet::Util.sync(:puppetrun).synchronize(Sync::EX) do
            if !lockfile.lock
                Puppet.notice "Lock file %s exists; skipping catalog run" %
                    lockfile.lockfile
            else
                got_lock = true
                begin
                    duration = thinmark do
                        self.getconfig
                    end
                rescue => detail
                    puts detail.backtrace if Puppet[:trace]
                    Puppet.err "Could not retrieve catalog: %s" % detail
                end

                if self.catalog
                    @catalog.retrieval_duration = duration
                    Puppet.notice "Starting catalog run" unless @local
                    benchmark(:notice, "Finished catalog run") do
                        @catalog.apply(options)
                    end
                end

                # Now close all of our existing http connections, since there's no
                # reason to leave them lying open.
                Puppet::Network::HttpPool.clear_http_instances
            end
            
            lockfile.unlock

            # Did we get HUPped during the run?  If so, then restart now that we're
            # done with the run.
            if self.restart?
                Process.kill(:HUP, $$)
            end
        end
    ensure
        # Just make sure we remove the lock file if we set it.
        lockfile.unlock if got_lock and lockfile.locked?
        clear()
    end

    def running?
        lockfile.locked?
    end

    # Store the classes in the classfile, but only if we're not local.
    def setclasses(ary)
        if @local
            return
        end
        unless ary and ary.length > 0
            Puppet.info "No classes to store"
            return
        end
        begin
            ::File.open(Puppet[:classfile], "w") { |f|
                f.puts ary.join("\n")
            }
        rescue => detail
            Puppet.err "Could not create class file %s: %s" %
                [Puppet[:classfile], detail]
        end
    end

    private

    def self.loaddir(dir, type)
        return unless FileTest.directory?(dir)

        Dir.entries(dir).find_all { |e| e =~ /\.rb$/ }.each do |file|
            fqfile = ::File.join(dir, file)
            begin
                Puppet.info "Loading %s %s" % 
                    [type, ::File.basename(file.sub(".rb",''))]
                Timeout::timeout(self.timeout) do
                    load fqfile
                end
            rescue => detail
                Puppet.warning "Could not load %s %s: %s" % [type, fqfile, detail]
            end
        end
    end

    def self.loadfacts
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = Puppet[:factpath].split(":").each do |dir|
            loaddir(dir, "fact")
        end
    end
    
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

    loadfacts()
    
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

        return textobjects
    end

    private

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
