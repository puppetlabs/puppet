require 'puppet'
require 'puppet/util/pidlock'
require 'puppet/external/event-loop'

# A module that handles operations common to all daemons.  This is included
# into the Server and Client base classes.
class Puppet::Daemon
    attr_accessor :agent, :server, :argv

    def daemonname
        Puppet[:name]
    end

    # Put the daemon into the background.
    def daemonize
        if pid = fork()
            Process.detach(pid)
            exit(0)
        end

        create_pidfile()

        # Get rid of console logging
        Puppet::Util::Log.close(:console)

        Process.setsid
        Dir.chdir("/")
        begin
            $stdin.reopen "/dev/null"
            $stdout.reopen "/dev/null", "a"
            $stderr.reopen $stdout
            Puppet::Util::Log.reopen
        rescue => detail
            Puppet.err "Could not start %s: %s" % [Puppet[:name], detail]
            Puppet::Util::secure_open("/tmp/daemonout", "w") { |f|
                f.puts "Could not start %s: %s" % [Puppet[:name], detail]
            }
            exit(12)
        end
    end

    # Create a pidfile for our daemon, so we can be stopped and others
    # don't try to start.
    def create_pidfile
        Puppet::Util.sync(Puppet[:name]).synchronize(Sync::EX) do
            unless Puppet::Util::Pidlock.new(pidfile).lock
                raise "Could not create PID file: %s" % [pidfile]
            end
        end
    end

    # Provide the path to our pidfile.
    def pidfile
        Puppet[:pidfile]
    end

    def reexec
        raise Puppet::DevError, "Cannot reexec unless ARGV arguments are set" unless argv
        command = $0 + " " + argv.join(" ")
        Puppet.notice "Restarting with '%s'" % command
        stop(:exit => false)
        exec(command)
    end

    def reload
        return unless agent
        if agent.running?
            Puppet.notice "Not triggering already-running agent"
            return
        end

        agent.run
    end

    # Remove the pid file for our daemon.
    def remove_pidfile
        Puppet::Util.sync(Puppet[:name]).synchronize(Sync::EX) do
            locker = Puppet::Util::Pidlock.new(pidfile)
            if locker.locked?
                locker.unlock or Puppet.err "Could not remove PID file %s" % [pidfile]
            end
        end
    end

    def restart
        if agent and agent.running?
            agent.configure_delayed_restart
        else
            reexec
        end
    end

    def reopen_logs
        Puppet::Util::Log.reopen
    end

    # Trap a couple of the main signals.  This should probably be handled
    # in a way that anyone else can register callbacks for traps, but, eh.
    def set_signal_traps
        {:INT => :stop, :TERM => :stop, :HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs}.each do |signal, method|
            trap(signal) do
                Puppet.notice "Caught #{signal}; calling #{method}"
                send(method)
            end
        end
    end

    # Stop everything
    def stop(args = {:exit => true})
        server.stop if server

        agent.stop if agent

        remove_pidfile()

        Puppet::Util::Log.close_all

        exit if args[:exit]
    end

    def start
        set_signal_traps

        create_pidfile

        raise Puppet::DevError, "Daemons must have an agent, server, or both" unless agent or server
        agent.start if agent
        server.start if server

        EventLoop.current.run
    end
end

