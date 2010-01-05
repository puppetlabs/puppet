require 'puppet'
require 'puppet/util/pidlock'

# A module that handles operations common to all daemons.  This is included
# into the Server and Client base classes.
module Puppet::Daemon
    include Puppet::Util

    def daemonname
        Puppet[:name]
    end

    # Put the daemon into the background.
    def daemonize
        if pid = fork()
            Process.detach(pid)
            exit(0)
        end
        
        setpidfile()

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
            Puppet::Util.secure_open("/tmp/daemonout", "w") { |f|
                f.puts "Could not start %s: %s" % [Puppet[:name], detail]
            }
            Puppet.err "Could not start %s: %s" % [Puppet[:name], detail]
            exit(12)
        end
    end

    # The path to the pid file for this server
    def pidfile
        if Puppet[:pidfile] != ""
            Puppet[:pidfile]
        else
            File.join(Puppet[:rundir], daemonname() + ".pid")
        end
    end

    # Remove the pid file
    def rmpidfile
        threadlock(:pidfile) do
            locker = Puppet::Util::Pidlock.new(pidfile)
            if locker.locked?
                locker.unlock or Puppet.err "Could not remove PID file %s" % [pidfile]
            end
        end
    end

    # Create the pid file.
    def setpidfile
        threadlock(:pidfile) do
            unless Puppet::Util::Pidlock.new(pidfile).lock
                Puppet.err("Could not create PID file: %s" % [pidfile])
                exit(74)
            end
        end
    end

    # Shut down our server
    def shutdown
        # Remove our pid file
        rmpidfile()

        # And close all logs except the console.
        Puppet::Util::Log.destinations.reject { |d| d == :console }.each do |dest|
            Puppet::Util::Log.close(dest)
        end

        super
    end
end

