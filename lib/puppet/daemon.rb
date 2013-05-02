require 'puppet'
require 'puppet/util/pidlock'
require 'puppet/application'
require 'puppet/scheduler'

# A module that handles operations common to all daemons.  This is included
# into the Server and Client base classes.
class Puppet::Daemon
  attr_accessor :agent, :server, :argv

  def daemonname
    Puppet.run_mode.name
  end

  # Put the daemon into the background.
  def daemonize
    if pid = fork
      Process.detach(pid)
      exit(0)
    end

    create_pidfile

    # Get rid of console logging
    Puppet::Util::Log.close(:console)

    Process.setsid
    Dir.chdir("/")
  end

  # Close stdin/stdout/stderr so that we can finish our transition into 'daemon' mode.
  # @return nil
  def self.close_streams()
    Puppet.debug("Closing streams for daemon mode")
    begin
      $stdin.reopen "/dev/null"
      $stdout.reopen "/dev/null", "a"
      $stderr.reopen $stdout
      Puppet::Util::Log.reopen
      Puppet.debug("Finished closing streams for daemon mode")
    rescue => detail
      Puppet.err "Could not start #{Puppet.run_mode.name}: #{detail}"
      Puppet::Util::replace_file("/tmp/daemonout", 0644) do |f|
        f.puts "Could not start #{Puppet.run_mode.name}: #{detail}"
      end
      exit(12)
    end
  end

  # Convenience signature for calling Puppet::Daemon.close_streams
  def close_streams()
    Puppet::Daemon.close_streams
  end

  # Create a pidfile for our daemon, so we can be stopped and others
  # don't try to start.
  def create_pidfile
    Puppet::Util.synchronize_on(Puppet.run_mode.name,Sync::EX) do
      raise "Could not create PID file: #{pidfile}" unless Puppet::Util::Pidlock.new(pidfile).lock
    end
  end

  # Provide the path to our pidfile.
  def pidfile
    Puppet[:pidfile]
  end

  def reexec
    raise Puppet::DevError, "Cannot reexec unless ARGV arguments are set" unless argv
    command = $0 + " " + argv.join(" ")
    Puppet.notice "Restarting with '#{command}'"
    stop(:exit => false)
    exec(command)
  end

  def reload
    return unless agent
    if agent.running?
      Puppet.notice "Not triggering already-running agent"
      return
    end

    agent.run({:splay => false})
  end

  # Remove the pid file for our daemon.
  def remove_pidfile
    Puppet::Util.synchronize_on(Puppet.run_mode.name,Sync::EX) do
      Puppet::Util::Pidlock.new(pidfile).unlock
    end
  end

  def restart
    Puppet::Application.restart!
    reexec unless agent and agent.running?
  end

  def reopen_logs
    Puppet::Util::Log.reopen
  end

  # Trap a couple of the main signals.  This should probably be handled
  # in a way that anyone else can register callbacks for traps, but, eh.
  def set_signal_traps
    signals = {:INT => :stop, :TERM => :stop }
    # extended signals not supported under windows
    signals.update({:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs }) unless Puppet.features.microsoft_windows?
    signals.each do |signal, method|
      Signal.trap(signal) do
        Puppet.notice "Caught #{signal}; calling #{method}"
        send(method)
      end
    end
  end

  # Stop everything
  def stop(args = {:exit => true})
    Puppet::Application.stop!

    server.stop if server

    remove_pidfile

    Puppet::Util::Log.close_all

    exit if args[:exit]
  end

  def start
    set_signal_traps

    create_pidfile

    raise Puppet::DevError, "Daemons must have an agent, server, or both" unless agent or server

    # Start the listening server, if required.
    server.start if server

    # now that the server has started, we've waited just about as long as possible to close
    #  our streams and become a "real" daemon process.  This is in hopes of allowing
    #  errors to have the console available as a fallback for logging for as long as
    #  possible.
    close_streams if Puppet[:daemonize]

    # Finally, loop forever running events - or, at least, until we exit.
    run_event_loop

    server.wait_for_shutdown if server
  end

  def run_event_loop
    agent_run = Puppet::Scheduler.create_job(Puppet[:runinterval], Puppet[:splay], Puppet[:splaylimit]) do
      # Splay for the daemon is handled in the scheduler
      agent.run(:splay => false)
    end

    reparse_run = Puppet::Scheduler.create_job(Puppet[:filetimeout]) do
      Puppet.settings.reparse_config_files
      agent_run.run_interval = Puppet[:runinterval]
      if Puppet[:filetimeout] == 0
        reparse_run.disable
      else
        reparse_run.run_interval = Puppet[:filetimeout]
      end
    end

    reparse_run.disable if Puppet[:filetimeout] == 0
    agent_run.disable unless agent

    scheduler = Puppet::Scheduler::Scheduler.new([reparse_run, agent_run])

    scheduler.run_loop
  end
end

