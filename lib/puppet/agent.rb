require 'sync'
require 'puppet/external/event-loop'

# A general class for triggering a run of another
# class.
class Puppet::Agent
    require 'puppet/agent/locker'
    include Puppet::Agent::Locker

    require 'puppet/agent/runner'

    attr_reader :client_class, :client, :needing_restart, :splayed
    attr_accessor :stopping

    def configure_delayed_restart
        @needing_restart = true
    end

    # Just so we can specify that we are "the" instance.
    def initialize(client_class)
        @splayed = false

        @client_class = client_class
    end

    def lockfile_path
        client_class.lockfile_path
    end

    def needing_restart?
        @needing_restart
    end

    def restart
        configure_delayed_restart and return if running?
        Process.kill(:HUP, $$)
        @needing_restart = false
    end

    # Perform a run with our client.
    def run(*args)
        if running?
            Puppet.notice "Run of %s already in progress; skipping" % client_class
            return
        end
        if stopping?
            Puppet.notice "In shutdown progress; skipping run"
            return
        end
        splay
        with_client do |client|
            begin
                sync.synchronize { lock { client.run(*args) } }
            rescue SystemExit,NoMemoryError
                raise
            rescue Exception => detail
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not run %s: %s" % [client_class, detail]
            end
        end
    end

    def stop
        if self.stopping?
            Puppet.notice "Already in shutdown"
            return
        end
        self.stopping = true
        if client and client.respond_to?(:stop)
            begin
                client.stop
            rescue
                puts detail.backtrace if Puppet[:trace]
                Puppet.err "Could not stop %s: %s" % [client_class, detail]
            end
        end
    ensure
        self.stopping = false
    end

    def stopping?
        stopping
    end

    # Have we splayed already?
    def splayed?
        splayed
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

    # Start listening for events.  We're pretty much just listening for
    # timer events here.
    def start
        # Create our timer.  Puppet will handle observing it and such.
        timer = EventLoop::Timer.new(:interval => Puppet[:runinterval], :tolerance => 1, :start? => true) do
            run()
        end

        # Run once before we start following the timer
        timer.sound_alarm
    end

    def sync
        unless defined?(@sync) and @sync
            @sync = Sync.new
        end
        @sync
    end

    private

    # Create and yield a client instance, keeping a reference
    # to it during the yield.
    def with_client
        begin
            @client = client_class.new
        rescue SystemExit,NoMemoryError
            raise
        rescue Exception => detail
            puts detail.backtrace if Puppet[:trace]
            Puppet.err "Could not create instance of %s: %s" % [client_class, detail]
            return
        end
        yield @client
    ensure
        @client = nil
    end
end
