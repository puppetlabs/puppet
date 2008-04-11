# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'
require 'puppet/network/http_pool'

class Puppet::Network::Client::Master < Puppet::Network::Client
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

    def self.facts
        # Retrieve the facts from the central server.
        if Puppet[:factsync]
            self.getfacts()
        end
        
        down = Puppet[:downcasefacts]

        facts = Facter.to_hash.inject({}) do |newhash, array|
            name, fact = array
            if down
                newhash[name] = fact.to_s.downcase
            else
                newhash[name] = fact.to_s
            end
            newhash
        end

        # Add our client version to the list of facts, so people can use it
        # in their manifests
        facts["clientversion"] = Puppet.version.to_s

        # And add our environment as a fact.
        unless facts.include?("environment")
            facts["environment"] = Puppet[:environment]
        end
 
        facts
    end

    # Return the list of dynamic facts as an array of symbols
    # NOTE:LAK(2008/04/10): This code is currently unused, since we now always
    # recompile.
    def self.dynamic_facts
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = Puppet.settings[:dynamicfacts].split(/\s*,\s*/).collect { |fact| fact.downcase }
    end

    # Cache the config
    def cache(text)
        Puppet.info "Caching catalog at %s" % self.cachefile
        confdir = ::File.dirname(Puppet[:localconfig])
        ::File.open(self.cachefile + ".tmp", "w", 0660) { |f|
            f.print text
        }
        ::File.rename(self.cachefile + ".tmp", self.cachefile)
    end

    def cachefile
        unless defined? @cachefile
            @cachefile = Puppet[:localconfig] + ".yaml"
        end
        @cachefile
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

    # Let the daemon run again, freely in the filesystem.  Frolick, little
    # daemon!
    def enable
        lockfile.unlock(:anonymous => true)
    end

    # Stop the daemon from making any catalog runs.
    def disable
        lockfile.lock(:anonymous => true)
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

        # Retrieve the plugins.
        getplugins() if Puppet[:pluginsync]

        Puppet.debug("Retrieving catalog")

        # If we can't retrieve the catalog, just return, which will either
        # fail, or use the in-memory catalog.
        unless yaml_objects = get_actual_config(facts)
            use_cached_config(true)
            return
        end

        begin
            objects = YAML.load(yaml_objects)
        rescue => detail
            msg = "Configuration could not be translated from yaml"
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

        if ! @catalog.from_cache
            self.cache(yaml_objects)
        end

        # Keep the state database up to date.
        @catalog.host_config = true
    end
    
    # A simple proxy method, so it's easy to test.
    def getplugins
        self.class.getplugins
    end
    
    # Just so we can specify that we are "the" instance.
    def initialize(*args)
        Puppet.settings.use(:main, :ssl, :puppetd)
        super

        self.class.instance = self
        @running = false
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

    # Download files from the remote server, returning a list of all
    # changed files.
    def self.download(args)
        hash = {
            :path => args[:dest],
            :recurse => true,
            :source => args[:source],
            :tag => "#{args[:name]}s",
            :owner => Process.uid,
            :group => Process.gid,
            :purge => true,
            :force => true,
            :backup => false,
            :noop => false
        }

        if args[:ignore]
            hash[:ignore] = args[:ignore].split(/\s+/)
        end
        downconfig = Puppet::Node::Catalog.new("downloading")
        downconfig.add_resource Puppet::Type.type(:file).create(hash)
        
        Puppet.info "Retrieving #{args[:name]}s"

        files = []
        begin
            Timeout::timeout(self.timeout) do
                downconfig.apply do |trans|
                    trans.changed?.find_all do |resource|
                        yield resource if block_given?
                        files << resource[:path]
                    end
                end
            end
        rescue Puppet::Error, Timeout::Error => detail
            if Puppet[:debug]
                puts detail.backtrace
            end
            Puppet.err "Could not retrieve #{args[:name]}s: %s" % detail
        end

        # Now clean up after ourselves
        downconfig.clear

        return files
    end

    # Retrieve facts from the central server.
    def self.getfacts
        # Download the new facts
        path = Puppet[:factpath].split(":")
        files = []
        download(:dest => Puppet[:factdest], :source => Puppet[:factsource],
            :ignore => Puppet[:factsignore], :name => "fact") do |resource|

            next unless path.include?(::File.dirname(resource[:path]))

            files << resource[:path]
        end
    ensure
        # Clear all existing definitions.
        Facter.clear

        # Reload everything.
        if Facter.respond_to? :loadfacts
            Facter.loadfacts
        elsif Facter.respond_to? :load
            Facter.load
        else
            raise Puppet::Error,
                "You must upgrade your version of Facter to use centralized facts"
        end

        # This loads all existing facts and any new ones.  We have to remove and
        # reload because there's no way to unload specific facts.
        loadfacts()
    end

    # Retrieve the plugins from the central server.  We only have to load the
    # changed plugins, because Puppet::Type loads plugins on demand.
    def self.getplugins
        download(:dest => Puppet[:plugindest], :source => Puppet[:pluginsource],
            :ignore => Puppet[:pluginsignore], :name => "plugin") do |resource|

            next if FileTest.directory?(resource[:path])
            path = resource[:path].sub(Puppet[:plugindest], '').sub(/^\/+/, '')
            unless Puppet::Util::Autoload.loaded?(path)
                next
            end

            begin
                Puppet.info "Reloading downloaded file %s" % path
                load resource[:path]
            rescue => detail
                Puppet.warning "Could not reload downloaded file %s: %s" %
                    [resource[:path], detail]
            end
        end
    end

    def self.loaddir(dir, type)
        return unless FileTest.directory?(dir)

        Dir.entries(dir).find_all { |e| e =~ /\.rb$/ }.each do |file|
            fqfile = ::File.join(dir, file)
            begin
                Puppet.info "Loading #{type} %s" % ::File.basename(file.sub(".rb",''))
                Timeout::timeout(self.timeout) do
                    load fqfile
                end
            rescue => detail
                Puppet.warning "Could not load #{type} %s: %s" % [fqfile, detail]
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
                textobjects = @driver.getconfig(textfacts, "yaml")
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

    def lockfile
        unless defined?(@lockfile)
            @lockfile = Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile])
        end

        @lockfile
    end

    # Sleep when splay is enabled; else just return.
    def splay
        return unless Puppet[:splay]

        limit = Integer(Puppet[:splaylimit])

        # Pick a splay time and then cache it.
        unless time = Puppet::Util::Storage.cache(:configuration)[:splay_time]
            time = rand(limit)
            Puppet::Util::Storage.cache(:configuration)[:splay_time] = time
        end

        Puppet.info "Sleeping for %s seconds (splay is enabled)" % time
        sleep(time)
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
