# The client for interacting with the puppetmaster config server.
require 'sync'

class Puppet::Client::MasterClient < Puppet::Client
    unless defined? @@sync
        @@sync = Sync.new
    end

    @handler = Puppet::Server::Master

    Puppet.setdefaults("puppetd",
        :puppetdlockfile => [ "$statedir/puppetdlock",
            "A lock file to temporarily stop puppetd from doing anything."],
        :usecacheonfailure => [true,
            "Whether to use the cached configuration when the remote
            configuration will not compile.  This option is useful for testing
            new configurations, where you want to fix the broken configuration
            rather than reverting to a known-good one."
        ],
        :downcasefacts => [false,
            "Whether facts should be made all lowercase when sent to the server."]
    )

    Puppet.setdefaults(:puppetd,
        :reportserver => ["$server",
            "The server to which to send transaction reports."
        ],
        :report => [false,
            "Whether to send reports after every transaction."
        ]
    )

    # Plugin information.
    Puppet.setdefaults("puppet",
        :pluginpath => ["$vardir/plugins",
            "Where Puppet should look for plugins.  Multiple directories should
            be colon-separated, like normal PATH variables."],
        :plugindest => ["$vardir/plugins",
            "Where Puppet should store plugins that it pulls down from the central
            server."],
        :pluginsource => ["puppet://$server/plugins",
            "From where to retrieve plugins.  The standard Puppet ``file`` type
             is used for retrieval, so anything that is a valid file source can
             be used here."],
        :pluginsync => [false,
            "Whether plugins should be synced with the central server."],
        :pluginsignore => [".svn CVS",
            "What files to ignore when pulling down plugins."]
    )

    # Central fact information.
    Puppet.setdefaults("puppet",
        :factpath => ["$vardir/facts",
            "Where Puppet should look for facts.  Multiple directories should
            be colon-separated, like normal PATH variables."],
        :factdest => ["$vardir/facts",
            "Where Puppet should store facts that it pulls down from the central
            server."],
        :factsource => ["puppet://$server/facts",
            "From where to retrieve facts.  The standard Puppet ``file`` type
             is used for retrieval, so anything that is a valid file source can
             be used here."],
        :factsync => [false,
            "Whether facts should be synced with the central server."],
        :factsignore => [".svn CVS",
            "What files to ignore when pulling down facts."]
    )

    @drivername = :Master

    attr_accessor :objects
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

        facts = {}
        Facter.each { |name,fact|
            if down
                facts[name] = fact.to_s.downcase
            else
                facts[name] = fact.to_s
            end
        }

        # Add our client version to the list of facts, so people can use it
        # in their manifests
        facts["clientversion"] = Puppet.version.to_s

        facts
    end

    # This method actually applies the configuration.
    def apply(tags = nil, ignoreschedules = false)
        unless defined? @objects
            raise Puppet::Error, "Cannot apply; objects not defined"
        end

        transaction = @objects.evaluate

        if tags
            transaction.tags = tags
        end

        if ignoreschedules
            transaction.ignoreschedules = true
        end

        transaction.addtimes :config_retrieval => @configtime

        begin
            transaction.evaluate
        rescue Puppet::Error => detail
            Puppet.err "Could not apply complete configuration: %s" %
                detail
        rescue => detail
            Puppet.err "Found a bug: %s" % detail
            if Puppet[:trace]
                puts detail.backtrace
            end
        ensure
            Puppet::Storage.store
        end
        
        if Puppet[:report]
            report(transaction)
        end

        return transaction
    ensure
        if defined? transaction and transaction
            transaction.cleanup
        end
    end

    # Cache the config
    def cache(text)
        Puppet.info "Caching configuration at %s" % self.cachefile
        confdir = File.dirname(Puppet[:localconfig])
        File.open(self.cachefile + ".tmp", "w", 0660) { |f|
            f.print text
        }
        File.rename(self.cachefile + ".tmp", self.cachefile)
    end

    def cachefile
        unless defined? @cachefile
            @cachefile = Puppet[:localconfig] + ".yaml"
        end
        @cachefile
    end

    def clear
        #@objects = nil
        @objects.remove(true)
        Puppet::Type.allclear
    end

    # Initialize and load storage
    def dostorage
        begin
            Puppet::Storage.load
            @compile_time ||= Puppet::Storage.cache(:configuration)[:compile_time]
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            Puppet.err "Corrupt state file %s: %s" % [Puppet[:statefile], detail]
            begin
                File.unlink(Puppet[:statefile])
                retry
            rescue => detail
                raise Puppet::Error.new("Cannot remove %s: %s" %
                    [Puppet[:statefile], detail])
            end
        end
    end

    # Check whether our configuration is up to date
    def fresh?
        unless self.compile_time
            return false
        end

        # We're willing to give a 2 second drift
        if @driver.freshness - @compile_time.to_i < 1
            return true
        else
            return false
        end
    end

    # Let the daemon run again, freely in the filesystem.  Frolick, little
    # daemon!
    def enable
        Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile]).unlock(:anonymous => true)
    end

    # Stop the daemon from making any configuration runs.
    def disable
        Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile]).lock(:anonymous => true)
    end

    # Retrieve the config from a remote server.  If this fails, then
    # use the cached copy.
    def getconfig
        dostorage()
        if self.fresh?
            Puppet.info "Config is up to date"
            unless defined? @objects
                begin
                    @objects = YAML.load(self.retrievecache).to_type
                rescue => detail
                    Puppet.warning "Could not load cached configuration: %s" % detail
                end
            end
            return
        end
        Puppet.debug("getting config")

        # Retrieve the plugins.
        if Puppet[:pluginsync]
            getplugins()
        end

        facts = self.class.facts

        unless facts.length > 0
            raise Puppet::ClientError.new(
                "Could not retrieve any facts"
            )
        end

        unless objects = get_actual_config(facts)
            @objects = nil
            return
        end

        unless objects.is_a?(Puppet::TransBucket)
            raise NetworkClientError,
                "Invalid returned objects of type %s" % objects.class
        end

        self.setclasses(objects.classes)

        # Clear all existing objects, so we can recreate our stack.
        if defined? @objects
            Puppet::Type.allclear

            # Make sure all of the objects are really gone.
            @objects.remove(true)
        end
        @objects = nil

        # First create the default scheduling objects
        Puppet::Type.type(:schedule).mkdefaultschedules
        
        # And filebuckets
        Puppet::Type.type(:filebucket).mkdefaultbucket

        # Now convert the objects to real Puppet objects
        @objects = objects.to_type

        if @objects.nil?
            raise Puppet::Error, "Configuration could not be processed"
        end

        # and perform any necessary final actions before we evaluate.
        @objects.finalize

        return @objects
    end
    
    # A simple proxy method, so it's easy to test.
    def getplugins
        self.class.getplugins
    end
    
    # Just so we can specify that we are "the" instance.
    def initialize(*args)
        Puppet.config.use(:puppet, :sslcertificates, :puppetd)
        super

        # This might be nil
        @configtime = 0

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
            return File.read(self.cachefile)
        else
            return ""
        end
    end

    # The code that actually runs the configuration.  
    def run(tags = nil, ignoreschedules = false)
        lockfile = Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile])
        
        Puppet::Util.sync(:puppetrun).synchronize(Sync::EX) do
            if !lockfile.lock
                Puppet.notice "Lock file %s exists; skipping configuration run" %
                    lockfile.lockfile
            else
                @running = true
                @configtime = thinmark do
                    self.getconfig
                end

                if defined? @objects and @objects
                    unless @local
                        Puppet.notice "Starting configuration run"
                    end
                    benchmark(:notice, "Finished configuration run") do
                        self.apply(tags, ignoreschedules)
                    end
                end
                @running = false
            end
            
            lockfile.unlock

            # Did we get HUPped during the run?  If so, then restart now that we're
            # done with the run.
            if self.restart?
                Process.kill(:HUP, $$)
            end
        end
    end

    def running?
        @running
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
            File.open(Puppet[:classfile], "w") { |f|
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
        objects = Puppet::Type.type(:component).create(
            :name => "#{args[:name]}_collector"
        )
        hash = {
            :path => args[:dest],
            :recurse => true,
            :source => args[:source],
            :tag => "#{args[:name]}s",
            :owner => Process.uid,
            :group => Process.gid,
            :backup => false
        }

        if args[:ignore]
            hash[:ignore] = args[:ignore].split(/\s+/)
        end
        objects.push Puppet::Type.type(:file).create(hash)

        Puppet.info "Retrieving #{args[:name]}s"

        begin
            trans = objects.evaluate
            trans.ignoretags = true
            trans.evaluate
        rescue Puppet::Error => detail
            if Puppet[:debug]
                puts detail.backtrace
            end
            Puppet.err "Could not retrieve #{args[:name]}s: %s" % detail
        end

        # Now source all of the changed objects, but only source those
        # that are top-level.
        files = []
        trans.changed?.find_all do |object|
            yield object if block_given?
            files << object[:path]
        end
        trans.cleanup

        # Now clean up after ourselves
        objects.remove
        files
    end

    # Retrieve facts from the central server.
    def self.getfacts
        # Clear all existing definitions.
        Facter.clear

        # Download the new facts
        path = Puppet[:factpath].split(":")
        files = []
        download(:dest => Puppet[:factdest], :source => Puppet[:factsource],
            :ignore => Puppet[:factsignore], :name => "fact") do |object|

            next unless path.include?(File.dirname(object[:path]))

            files << object[:path]

        end

    ensure
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
        path = Puppet[:pluginpath].split(":")
        download(:dest => Puppet[:plugindest], :source => Puppet[:pluginsource],
            :ignore => Puppet[:pluginsignore], :name => "plugin") do |object|

            next unless path.include?(File.dirname(object[:path]))

            begin
                Puppet.info "Reloading plugin %s" %
                    File.basename(File.basename(object[:path])).sub(".rb",'')
                load object[:path]
            rescue => detail
                Puppet.warning "Could not reload plugin %s: %s" %
                    [object[:path], detail]
            end
        end
    end

    def self.loaddir(dir, type)
        return unless FileTest.directory?(dir)

        Dir.entries(dir).find_all { |e| e =~ /\.rb$/ }.each do |file|
            fqfile = File.join(dir, file)
            begin
                Puppet.info "Loading #{type} %s" %
                    File.basename(file.sub(".rb",''))
                load fqfile
            rescue => detail
                Puppet.warning "Could not load #{type} %s: %s" % [fqfile, detail]
            end
        end
    end

    def self.loadfacts
        Puppet[:factpath].split(":").each do |dir|
            loaddir(dir, "fact")
        end
    end
    
    # Send off the transaction report.
    def report(transaction)
        begin
            report = transaction.report()
            if Puppet[:rrdgraph] == true
                report.graph()
            end
            reportclient().report(report)
        rescue => detail
            Puppet.err "Reporting failed: %s" % detail
        end
    end

    def reportclient
        unless defined? @reportclient
            @reportclient = Puppet::Client::Reporter.new(
                :Server => Puppet[:reportserver]
            )
        end

        @reportclient
    end

    loadfacts()
    
    private
    
    # Actually retrieve the configuration, either from the server or from a local master.
    def get_actual_config(facts)
        if @local
            return get_local_config(facts)
        else
            return get_remote_config(facts)
        end
    end
    
    # Retrieve a configuration from a local master.
    def get_local_config(facts)
        # If we're local, we don't have to do any of the conversion
        # stuff.
        objects = @driver.getconfig(facts, "yaml")
        @compile_time = Time.now

        if objects == ""
            raise Puppet::Error, "Could not retrieve configuration"
        end
        
        return objects
    end
    
    # Retrieve a config from a remote master.
    def get_remote_config(facts)
        textobjects = ""

        textfacts = CGI.escape(YAML.dump(facts))

        benchmark(:debug, "Retrieved configuration") do
            # error handling for this is done in the network client
            begin
                textobjects = @driver.getconfig(textfacts, "yaml")
            rescue => detail
                Puppet.err "Could not retrieve configuration: %s" % detail

                unless Puppet[:usecacheonfailure]
                    @objects = nil
                    Puppet.warning "Not using cache on failed configuration"
                    return
                end
            end
        end

        fromcache = false
        if textobjects == ""
            textobjects = self.retrievecache
            if textobjects == ""
                raise Puppet::Error.new(
                    "Cannot connect to server and there is no cached configuration"
                )
            end
            Puppet.warning "Could not get config; using cached copy"
            fromcache = true
        else
            @compile_time = Time.now
            Puppet::Storage.cache(:configuration)[:compile_time] = @compile_time
        end

        begin
            textobjects = CGI.unescape(textobjects)
        rescue => detail
            raise Puppet::Error, "Could not CGI.unescape configuration"
        end

        if @cache and ! fromcache
            self.cache(textobjects)
        end

        begin
            objects = YAML.load(textobjects)
        rescue => detail
            raise Puppet::Error,
                "Could not understand configuration: %s" %
                detail.to_s
        end
        
        return objects
    end
end

# $Id$
