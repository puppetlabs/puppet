class Puppet::Agent
    # enable/disable

    # storage

    # locking

    # config timeout

    # setclasses

    # Retrieve our catalog, possibly from the cache.
    def catalog
        unless c = Puppet::Node::Catalog.find(name, :use_cache => (!Puppet[:ignorecache]))
            raise "Could not retrieve catalog"
        end
        c.host_config = true
        c
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
        splay()

        download_plugins()

        upload_facts()

        catalog = download_catalog()

        apply(catalog)
    end

    # Sleep for a random but consistent period of time if configured to
    # do so.
    def splay
        return unless Puppet[:splay]

        time = splay_time()

        Puppet.info "Sleeping for %s seconds (splay is enabled)" % time
        sleep(time)
    end

    def start
#        # Create our timer.  Puppet will handle observing it and such.
#        timer = Puppet.newtimer(
#            :interval => Puppet[:runinterval],
#            :tolerance => 1,
#            :start? => true
#        ) do
#            begin
#                self.runnow if self.scheduled?
#            rescue => detail
#                puts detail.backtrace if Puppet[:trace]
#                Puppet.err "Could not run client; got otherwise uncaught exception: %s" % detail
#            end
#        end
#
#        # Run once before we start following the timer
#        self.runnow
    end

    def download_catalog
        # LAK:NOTE This needs to handle skipping cached configs
        # if configured to do so.
        Puppet::Node::Catalog.find name
    end

    def download_plugins
        raise "Plugin downloads not implemented"
    end

    def upload_facts
    end

    def splay_time
        limit = Integer(Puppet[:splaylimit])

        # Pick a splay time and then cache it.
        unless time = Puppet::Util::Storage.cache(:configuration)[:splay_time]
            time = rand(limit)
            Puppet::Util::Storage.cache(:configuration)[:splay_time] = time
        end

        time
    end
end
