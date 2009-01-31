require 'puppet/external/event-loop'

# Manage events related to starting, stopping, and restarting
# contained services.
class Puppet::EventManager
    include SignalObserver

    attr_reader :services, :threads, :timers

    def initialize
        @services = []
        @threads = []
        @timers = []
    end

    # Create a new service that we're supposed to run
    def add_service(service)
        @services << service
    end

    def newthread(&block)
        @threads << Thread.new { yield }
    end

    # Add a timer we need to pay attention to.
    # This is only used by Puppet::Agent at the moment.
    def newtimer(hash, &block)
        timer = EventLoop::Timer.new(hash)
        @timers << timer

        if block_given?
            observe_signal(timer, :alarm, &block)
        end

        # In case they need it for something else.
        timer
    end

    # Reload any services that can be reloaded.  Really, this is just
    # meant to trigger an Agent run.
    def reload
        done = 0
        services.find_all { |service| service.respond_to?(:run) }.each do |service|
            if service.running?
                Puppet.notice "Not triggering already-running %s" % service.class
                next
            end

            Puppet.notice "Triggering a run of %s" % service.class

            done += 1
            begin
                service.run
            rescue => detail
                Puppet.err "Could not run service %s: %s" % [service.class, detail]
            end
        end

        unless done > 0
            Puppet.notice "No services were reloaded"
        end
    end

    def reopen_logs
        Puppet::Util::Log.reopen
    end

    # Relaunch the executable.
    def restart
        if client = @services.find { |s| s.is_a? Puppet::Network::Client.master } and client.running?
            client.restart
        else
            command = $0 + " " + self.args.join(" ")
            Puppet.notice "Restarting with '%s'" % command
            Puppet.shutdown(false)
            Puppet::Util::Log.reopen
            exec(command)
        end
    end

    # Trap a couple of the main signals.  This should probably be handled
    # in a way that anyone else can register callbacks for traps, but, eh.
    def set_traps
        {:INT => :shutdown, :TERM => :shutdown, :HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}.each do |signal, method|
            trap(signal) do
                Puppet.notice "Caught #{signal}; calling #{method}"
                send(method)
            end
        end
    end

    # Shutdown our server process, meaning stop all services and all threads.
    # Optionally, exit.
    def shutdown(leave = true)
        Puppet.notice "Shutting down"
        stop_timers

        stop_services

        stop_threads

        if leave
            exit(0)
        end
    end

    # Start all of our services and optionally our event loop, which blocks,
    # waiting for someone, somewhere, to generate events of some kind.
    def start
        start_services

        start_timers

        EventLoop.current.run
    end

    def start_services
        # Starting everything in its own thread.  Otherwise
        # we might have one service stop another service from
        # doing things like registering timers.
        @services.dup.each do |svc|
            begin
                svc.start
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                @services.delete svc
                Puppet.err "Could not start %s: %s" % [svc.class, detail]
            end
        end

        # We need to give the services a chance to register their timers before
        # we try to start monitoring them.
        sleep 0.5

        unless @services.length > 0
            Puppet.notice "No remaining services; exiting"
            exit(1)
        end
    end

    def stop_services
        # Stop our services
        services.each do |svc|
            begin
                timeout(20) do
                    svc.shutdown
                end
            rescue TimeoutError
                Puppet.err "%s could not shut down within 20 seconds" % svc.class
            end
        end
    end

    # Monitor all of the timers that have been set up.
    def start_timers
        timers.each do |timer|
            EventLoop.current.monitor_timer timer
        end
    end

    def stop_timers
        # Unmonitor our timers
        timers.each do |timer|
            EventLoop.current.ignore_timer timer
        end
    end

    def stop_threads
        # And wait for them all to die, giving a decent amount of time
        threads.each do |thr|
            begin
                timeout(20) do
                    thr.join
                end
            rescue TimeoutError
                # Just ignore this, since we can't intelligently provide a warning
            end
        end
    end
end
