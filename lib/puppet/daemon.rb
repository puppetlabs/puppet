# frozen_string_literal: true

require_relative '../puppet/application'
require_relative '../puppet/scheduler'

# Run periodic actions in a daemonized process.
#
# A Daemon has 2 parts:
#   * config reparse
#   * an agent that responds to #run
#
# The config reparse will occur periodically based on Settings. The agent
# is run periodically and a time interval based on Settings. The config
# reparse will update this time interval when needed.
#
# The Daemon is also responsible for signal handling, starting, stopping,
# running the agent on demand, and reloading the entire process. It ensures
# that only one Daemon is running by using a lockfile.
#
# @api private
class Puppet::Daemon
  SIGNAL_CHECK_INTERVAL = 5

  attr_accessor :argv
  attr_reader :signals, :agent

  def initialize(agent, pidfile, scheduler = Puppet::Scheduler::Scheduler.new())
    raise Puppet::DevError, _("Daemons must have an agent") unless agent

    @scheduler = scheduler
    @pidfile = pidfile
    @agent = agent
    @signals = []
  end

  def daemonname
    Puppet.run_mode.name
  end

  # Put the daemon into the background.
  def daemonize
    pid = fork
    if pid
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
  def self.close_streams
    Puppet.debug("Closing streams for daemon mode")
    begin
      $stdin.reopen "/dev/null"
      $stdout.reopen "/dev/null", "a"
      $stderr.reopen $stdout
      Puppet::Util::Log.reopen
      Puppet.debug("Finished closing streams for daemon mode")
    rescue => detail
      Puppet.err "Could not start #{Puppet.run_mode.name}: #{detail}"
      Puppet::Util.replace_file("/tmp/daemonout", 0o644) do |f|
        f.puts "Could not start #{Puppet.run_mode.name}: #{detail}"
      end
      exit(12)
    end
  end

  # Convenience signature for calling Puppet::Daemon.close_streams
  def close_streams
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
    agent.run({ :splay => false })
  rescue Puppet::LockError
    Puppet.notice "Not triggering already-running agent"
  end

  def restart
    Puppet::Application.restart!
    reexec
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
    unless Puppet::Util::Platform.windows?
      signals = { :HUP => :restart, :USR1 => :reload, :USR2 => :reopen_logs }
      signals.each do |signal, method|
        Signal.trap(signal) do
          Puppet.notice "Caught #{signal}; storing #{method}"
          @signals << method
        end
      end
    end
  end

  # Stop everything
  def stop(args = { :exit => true })
    Puppet::Application.stop!

    remove_pidfile

    Puppet::Util::Log.close_all

    exit if args[:exit]
  end

  def start
    create_pidfile
    run_event_loop
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

  # Loop forever running events - or, at least, until we exit.
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
      while method = @signals.shift # rubocop:disable Lint/AssignmentInCondition
        Puppet.notice "Processing #{method}"
        send(method)
      end
    end

    reparse_run.disable if Puppet[:filetimeout] == 0

    @scheduler.run_loop([reparse_run, agent_run, signal_loop])
  end
end
