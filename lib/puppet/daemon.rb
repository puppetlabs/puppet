require 'puppet/application'
require 'puppet/scheduler'

# Run periodic actions and a network server in a daemonized process.
#
# A Daemon has 3 parts:
#   * config reparse
#   * (optional) an agent that responds to #run
#   * (optional) a server that response to #stop, #start, and #wait_for_shutdown
#
# The config reparse will occur periodically based on Settings. The server will
# be started and is expected to manage its own run loop (and so not block the
# start call). The server will, however, still be waited for by using the
# #wait_for_shutdown method. The agent is run periodically and a time interval
# based on Settings. The config reparse will update this time interval when
# needed.
#
# The Daemon is also responsible for signal handling, starting, stopping,
# running the agent on demand, and reloading the entire process. It ensures
# that only one Daemon is running by using a lockfile.
#
# @api private
class Puppet::Daemon
  SIGNAL_CHECK_INTERVAL = 5

  attr_accessor :agent, :server, :argv
  attr_reader :signals

  def initialize(pidfile, scheduler = Puppet::Scheduler::Scheduler.new())
    @scheduler = scheduler
    @pidfile = pidfile
    @signals = []
  end

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

    close_streams
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

  def reexec
    raise Puppet::DevError, _("Cannot reexec unless ARGV arguments are set") unless argv
    command = $0 + " " + argv.join(" ")
    Puppet.notice "Restarting with '#{command}'"
    stop(:exit => false)
    exec(command)
  end

  def reload
    return unless agent
    agent.run({:splay => false})
  rescue Puppet::LockError
    Puppet.notice "Not triggering already-running agent"
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
    [:INT, :TERM].each do |signal|
      Signal.trap(signal) do
        Puppet.notice "Caught #{signal}; exiting"
        stop
      end
    end

    # extended signals not supported under windows
    if !Puppet.features.microsoft_windows?
      signals = {:HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs }
      signals.each do |signal, method|
        Signal.trap(signal) do
          Puppet.notice "Caught #{signal}; storing #{method}"
          @signals << method
        end
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
    create_pidfile

    raise Puppet::DevError, _("Daemons must have an agent, server, or both") unless agent or server

    # Start the listening server, if required.
    server.start if server

    # Finally, loop forever running events - or, at least, until we exit.
    run_event_loop

    server.wait_for_shutdown if server
  end

  private

  # Create a pidfile for our daemon, so we can be stopped and others
  # don't try to start.
  def create_pidfile
    raise "Could not create PID file: #{@pidfile.file_path}" unless @pidfile.lock
  end

  # Remove the pid file for our daemon.
  def remove_pidfile
    @pidfile.unlock
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

    signal_loop = Puppet::Scheduler.create_job(SIGNAL_CHECK_INTERVAL) do
      while method = @signals.shift
        Puppet.notice "Processing #{method}"
        send(method)
      end
    end

    reparse_run.disable if Puppet[:filetimeout] == 0
    agent_run.disable unless agent

    @scheduler.run_loop([reparse_run, agent_run, signal_loop])
  end
end
