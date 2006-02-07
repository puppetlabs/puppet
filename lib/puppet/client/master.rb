# The client for interacting with the puppetmaster config server.
class Puppet::Client::MasterClient < Puppet::Client
    @drivername = :Master

    def self.facts
        facts = {}
        Facter.each { |name,fact|
            facts[name] = fact.downcase
        }

        facts
    end

    # This method is how the client receives the tree of Transportable
    # objects.  For now, just descend into the tree and perform and
    # necessary manipulations.
    def apply
        Puppet.notice "Beginning configuration run"
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
        Puppet.notice "Finished configuration run"

        return transaction
    end

    # Cache the config
    def cache(text)
        Puppet.info "Caching configuration at %s" % self.cachefile
        confdir = File.dirname(Puppet[:localconfig])
        unless FileTest.exists?(confdir)
            Puppet.recmkdir(confdir, 0770)
        end
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

            # error handling for this is done in the network client
            begin
                textobjects = @driver.getconfig(textfacts, "yaml")
            rescue => detail
                Puppet.err "Could not retrieve configuration: %s" % detail
            end

            fromcache = false
            if textobjects == ""
                textobjects = self.retrievecache
                if textobjects == ""
                    raise Puppet::Error.new(
                        "Cannot connect to server and there is no cached configuration"
                    )
                end
                Puppet.notice "Could not get config; using cached copy"
                fromcache = true
            end

            begin
                textobjects = CGI.unescape(textobjects)
                @configstamp = Time.now.to_i
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

        if classes = objects.classes
            self.setclasses(classes)
        else
            Puppet.info "No classes to store"
        end

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
        Puppet::Type.finalize

        return @objects
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
        self.getconfig
        self.apply
    end

    def setclasses(ary)
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
