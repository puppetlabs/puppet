# The client for interacting with the puppetmaster config server.
require 'sync'
require 'timeout'

class Puppet::Network::Client::Master < Puppet::Network::Client
    unless defined? @@sync
        @@sync = Sync.new
    end

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
            Puppet.err "Got an uncaught exception of type %s: %s" %
                [detail.class, detail]
            if Puppet[:trace]
                puts detail.backtrace
            end
        ensure
            Puppet::Util::Storage.store
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
        @objects.remove(true)
        Puppet::Type.allclear
        mkdefault_objects
        @objects = nil
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

    # Check whether our configuration is up to date
    def fresh?(facts)
        if Puppet[:ignorecache]
            Puppet.notice "Ignoring cache"
            return false
        end
        unless self.compile_time
            Puppet.debug "No cached compile time"
            return false
        end
        if facts_changed?(facts)
            Puppet.info "Facts have changed; recompiling" unless local?
            return false
        end

        # We're willing to give a 2 second drift
        newcompile = @driver.freshness
        if newcompile - @compile_time.to_i < 1
            return true
        else
            Puppet.debug "Server compile time is %s vs %s" % [newcompile, @compile_time]
            return false
        end
    end

    # Let the daemon run again, freely in the filesystem.  Frolick, little
    # daemon!
    def enable
        lockfile.unlock(:anonymous => true)
    end

    # Stop the daemon from making any configuration runs.
    def disable
        lockfile.lock(:anonymous => true)
    end

    # Retrieve the config from a remote server.  If this fails, then
    # use the cached copy.
    def getconfig
        dostorage()

        facts = self.class.facts

        if self.objects or FileTest.exists?(self.cachefile)
            if self.fresh?(facts)
                Puppet.info "Config is up to date"
                if self.objects
                    return
                end
                if oldtext = self.retrievecache
                    begin
                        @objects = YAML.load(oldtext).to_type
                    rescue => detail
                        Puppet.warning "Could not load cached configuration: %s" % detail
                    end
                    return
                end
            end
        end
        Puppet.debug("getting config")

        # Retrieve the plugins.
        if Puppet[:pluginsync]
            getplugins()
        end

        unless facts.length > 0
            raise Puppet::Network::ClientError.new(
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
        if self.objects
            clear()
        end

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

        mkdefault_objects
    end

    # Make the default objects necessary for function.
    def mkdefault_objects
        # First create the default scheduling objects
        Puppet::Type.type(:schedule).mkdefaultschedules
        
        # And filebuckets
        Puppet::Type.type(:filebucket).mkdefaultbucket
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

    # The code that actually runs the configuration.  
    def run(tags = nil, ignoreschedules = false)
        got_lock = false
        Puppet::Util.sync(:puppetrun).synchronize(Sync::EX) do
            if !lockfile.lock
                Puppet.notice "Lock file %s exists; skipping configuration run" %
                    lockfile.lockfile
            else
                got_lock = true
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

        noop = Puppet[:noop]
        Puppet[:noop] = false

        begin
            trans = objects.evaluate
            trans.ignoretags = true
            Timeout::timeout(self.timeout) do
                trans.evaluate
            end
        rescue Puppet::Error, Timeout::Error => detail
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
    ensure
        # I can't imagine why this is necessary, but apparently at last one person has had problems with noop
        # being nil here.
        if noop.nil?
            Puppet[:noop] = false
        else
            Puppet[:noop] = noop
        end
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

            next unless path.include?(::File.dirname(object[:path]))

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

            next unless path.include?(::File.dirname(object[:path]))

            begin
                Puppet.info "Reloading plugin %s" %
                    ::File.basename(::File.basename(object[:path])).sub(".rb",'')
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
        Puppet[:factpath].split(":").each do |dir|
            loaddir(dir, "fact")
        end
    end
    
    def self.timeout
        @timeout = Puppet[:configtimeout]
        case @timeout
        when String:
            if @timeout =~ /^\d+$/
                @timeout = Integer(@timeout)
            else
                raise ArgumentError, "Configuration timeout must be an integer"
            end
        when Integer: # nothing
        else
            raise ArgumentError, "Configuration timeout must be an integer"
        end
    end
    
    # Send off the transaction report.
    def report(transaction)
        begin
            report = transaction.generate_report()
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
            @reportclient = Puppet::Network::Client.report.new(
                :Server => Puppet[:reportserver]
            )
        end

        @reportclient
    end

    loadfacts()
    
    private

    # Have the facts changed since we last compiled?
    def facts_changed?(facts)
        oldfacts = Puppet::Util::Storage.cache(:configuration)[:facts]
        newfacts = facts
        if oldfacts == newfacts
            return false
        else
#            unless oldfacts
#                puts "no old facts"
#                return true
#            end
#            newfacts.keys.each do |k|
#                unless newfacts[k] == oldfacts[k]
#                    puts "%s: %s vs %s" % [k, newfacts[k], oldfacts[k]]
#                end
#            end
            return true
        end
    end
    
    # Actually retrieve the configuration, either from the server or from a
    # local master.
    def get_actual_config(facts)
        if @local
            return get_local_config(facts)
        else
            begin
                Timeout::timeout(self.class.timeout) do
                    return get_remote_config(facts)
                end
            rescue Timeout::Error
                Puppet.err "Configuration retrieval timed out"
                return nil
            end
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
                begin
                    textobjects = CGI.unescape(textobjects)
                rescue => detail
                    raise Puppet::Error, "Could not CGI.unescape configuration"
                end

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
            unless textobjects = self.retrievecache
                raise Puppet::Error.new(
                    "Cannot connect to server and there is no cached configuration"
                )
            end
            Puppet.warning "Could not get config; using cached copy"
            fromcache = true
        else
            @compile_time = Time.now
            Puppet::Util::Storage.cache(:configuration)[:facts] = facts
            Puppet::Util::Storage.cache(:configuration)[:compile_time] = @compile_time
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

    def lockfile
        unless defined?(@lockfile)
            @lockfile = Puppet::Util::Pidlock.new(Puppet[:puppetdlockfile])
        end

        @lockfile
    end
end

# $Id$
