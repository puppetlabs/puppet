# The client for interacting with the puppetmaster config server.
require 'sync'

class Puppet::Client::MasterClient < Puppet::Client
    @@sync = Sync.new

    Puppet.setdefaults("puppetd",
        :puppetdlockfile => [ "$statedir/puppetdlock",
            "A lock file to temporarily stop puppetd from doing anything."],
        :usecacheonfailure => [true,
            "Whether to use the cached configuration when the remote
            configuration will not compile.  This option is useful for testing
            new configurations, where you want to fix the broken configuration
            rather than reverting to a known-good one."
        ]


    )

    @drivername = :Master

    def self.facts
        facts = {}
        Facter.each { |name,fact|
            facts[name] = fact.downcase
        }

        # Add our client version to the list of facts, so people can use it
        # in their manifests
        facts["clientversion"] = Puppet.version.to_s

        facts
    end

    # This method is how the client receives the tree of Transportable
    # objects.  For now, just descend into the tree and perform and
    # necessary manipulations.
    def apply
        dostorage()
        unless defined? @objects
            raise Puppet::Error, "Cannot apply; objects not defined"
        end

        #Puppet.err :yay
        #p @objects
        #Puppet.err :mark
        #@objects = @objects.to_type
        # this is a gross hack... but i don't see a good way around it
        # set all of the variables to empty
        Puppet::Transaction.init

        # For now we just evaluate the top-level object, but eventually
        # there will be schedules and such associated with each object,
        # and probably with the container itself.
        transaction = @objects.evaluate
        #transaction = Puppet::Transaction.new(objects)
        transaction.toplevel = true
        begin
            transaction.evaluate
        rescue Puppet::Error => detail
            Puppet.err "Could not apply complete configuration: %s" %
                detail
        rescue => detail
            Puppet.err "Found a bug: %s" % detail
            if Puppet[:debug]
                puts detail.backtrace
            end
        ensure
            Puppet::Storage.store
        end
        Puppet::Metric.gather
        Puppet::Metric.tally
        if Puppet[:rrdgraph] == true
            Metric.store
            Metric.graph
        end

        return transaction
    end

    # Cache the config
    def cache(text)
        Puppet.config.use(:puppet, :sslcertificates, :puppetd)
        Puppet.info "Caching configuration at %s" % self.cachefile
        confdir = File.dirname(Puppet[:localconfig])
        #unless FileTest.exists?(confdir)
        #    Puppet.recmkdir(confdir, 0770)
        #end
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

    # Disable running the configuration.  This can be used from the command line, but
    # is also used to make sure only one client is running at a time.
    def disable(running = false)
        text = nil
        if running
            text = Process.pid
        else
            text = ""
            Puppet.notice "Disabling puppetd"
        end
        Puppet.config.use(:puppet)
        begin
            File.open(Puppet[:puppetdlockfile], "w") { |f| f.puts text }
        rescue => detail
            raise Puppet::Error, "Could not lock puppetd: %s" % detail
        end
    end

    # Initialize and load storage
    def dostorage
        begin
            Puppet::Storage.init
            Puppet::Storage.load
        rescue => detail
            Puppet.err "Corrupt state file %s: %s" % [Puppet[:statefile], detail]
            begin
                File.unlink(Puppet[:statefile])
                retry
            rescue => detail
                raise Puppet::Error.new("Cannot remove %s: %s" %
                    [Puppet[statefile], detail])
            end
        end
    end

    # Enable running again.  This can be used from the command line, but
    # is also used to make sure only one client is running at a time.
    def enable(running = false)
        unless running
            Puppet.notice "Enabling puppetd"
        end
        if FileTest.exists? Puppet[:puppetdlockfile]
            File.unlink(Puppet[:puppetdlockfile])
        end
    end

    # Check whether our configuration is up to date
    def fresh?
        unless defined? @configstamp
            return false
        end

        # We're willing to give a 2 second drift
        if @driver.freshness - @configstamp < 1
            return true
        else
            return false
        end
    end

    # Retrieve the config from a remote server.  If this fails, then
    # use the cached copy.
    def getconfig
        if self.fresh?
            Puppet.info "Config is up to date"
            return
        end
        Puppet.debug("getting config")
        dostorage()

        facts = self.class.facts

        unless facts.length > 0
            raise Puppet::ClientError.new(
                "Could not retrieve any facts"
            )
        end

        objects = nil
        if @local
            # If we're local, we don't have to do any of the conversion
            # stuff.
            objects = @driver.getconfig(facts, "yaml")
            @configstamp = Time.now.to_i

            if objects == ""
                raise Puppet::Error, "Could not retrieve configuration"
            end
        else
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
                @configstamp = Time.now.to_i
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
        end

        unless objects.is_a?(Puppet::TransBucket)
            raise NetworkClientError,
                "Invalid returned objects of type %s" % objects.class
        end

        self.setclasses(objects.classes)

        # Clear all existing objects, so we can recreate our stack.
        if defined? @objects
            Puppet::Type.allclear
        end
        @objects = nil

        # First create the default scheduling objects
        Puppet.type(:schedule).mkdefaultschedules

        # Now convert the objects to real Puppet objects
        @objects = objects.to_type

        if @objects.nil?
            raise Puppet::Error, "Configuration could not be processed"
        end
        #@objects = objects

        # and perform any necessary final actions before we evaluate.
        @objects.finalize

        return @objects
    end

    # Make sure only one client runs at a time, and make sure only one thread
    # runs at a time.  However, this does not lock local clients -- you could have
    # as many separate puppet scripts running as you want.
    def lock
        if @local
            yield
        else
            @@sync.synchronize(Sync::EX) do
                disable(true)
                begin
                    yield
                ensure
                    enable(true)
                end
            end
        end
    end

    def locked?
        if FileTest.exists? Puppet[:puppetdlockfile]
            text = File.read(Puppet[:puppetdlockfile]).chomp
            if text =~ /\d+/
                return text
            else
                return true
            end
        else
            return false
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
    def run
        if pid = locked?
            t = ""
            if pid == true
                PUppet.notice "Locked by process %s" % pid
            end
            Puppet.notice "Lock file %s exists; skipping configuration run" %
                Puppet[:puppetdlockfile]
        else
            lock do
                self.getconfig

                if defined? @objects and @objects
                    unless @local
                        Puppet.notice "Starting configuration run"
                    end
                    benchmark(:notice, "Finished configuration run") do
                        self.apply
                    end
                end
            end
        end
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
end

# $Id$
