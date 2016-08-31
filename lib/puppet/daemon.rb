require 'puppet'
require 'puppet/util/pidlock'
require 'puppet/application'

# A module that handles operations common to all daemons.  This is included
# into the Server and Client base classes.
class Puppet::Daemon
  attr_accessor :agent, :server, :argv

  def daemonname
    Puppet[:name]
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
    begin
      $stdin.reopen "/dev/null"
      $stdout.reopen "/dev/null", "a"
      $stderr.reopen $stdout
      Puppet::Util::Log.reopen
    rescue => detail
      Puppet.err "Could not start #{Puppet[:name]}: #{detail}"
      Puppet::Util::replace_file("/tmp/daemonout", 0644) do |f|
        f.puts "Could not start #{Puppet[:name]}: #{detail}"
      end
      exit(12)
    end
  end

  # Create a pidfile for our daemon, so we can be stopped and others
  # don't try to start.
  def create_pidfile
    Puppet::Util.synchronize_on(Puppet[:name],Sync::EX) do
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

    agent.run
  end

  # Remove the pid file for our daemon.
  def remove_pidfile
    Puppet::Util.synchronize_on(Puppet[:name],Sync::EX) do
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

    # Finally, loop forever running events - or, at least, until we exit.
    run_event_loop
  end

  def run_event_loop
    # Now, we loop waiting for either the configuration file to change, or the
    # next agent run to be due.  Fun times.
    loop do
      now = Time.now.to_i

      # Work out when the next event is going to happen, and enact any
      # operations that triggers.
      if reparse_time = next_reparse_time(now)
        Puppet.settings.reparse if now >= reparse_time
      end

      if agent_time = next_agent_run_time(now)
        agent.run if now >= agent_time
      end

      # Finally, an interruptable able sleep until the next scheduled event,
      # assuming that there is some delay before they are due.
      how_long = [reparse_time, agent_time, now + 3600].compact.min - now
      how_long > 0 and select([], [], [], how_long)
    end
  end

  private
  def next_agent_run_time(now)
    return nil unless agent

    # We always want to run the agent on startup, so it was always before now.
    # Because 0 means "continuously run", `to_i` does the right thing when the
    # input is strange or badly formed by returning 0. Integer will raise,
    # which we don't want, and we want to protect against -1 or below.
    timeout = Puppet[:runinterval].to_i
    return now if timeout <= 0

    if @next_agent_run_time
      while @next_agent_run_time < now
        @next_agent_run_time += timeout
      end
    else
      # This is the first run - we need to set the run time, and also splay.
      @next_agent_run_time = now + timeout + splay
    end

    return @next_agent_run_time
  end

  def next_reparse_time(now)
    timeout = Puppet[:filetimeout].to_i
    return nil if timeout <= 0

    if @next_reparse_time
      # If our next run is in the past we need to calculate the next event in
      # the series - otherwise, return the current value.  Do this in steady
      # increments, but remember that we might be arbitrarily delayed by, eg,
      # an agent run that takes more than one timeout increment.
      while @next_reparse_time < now
        @next_reparse_time += timeout
      end
    else
      # Not yet initialized, so we wait for a full timeout before we reparse
      # the file on disk.
      @next_reparse_time = now + timeout
    end

    # ...and, finally, tell everyone when the wall time of the next run.
    return @next_reparse_time
  end

  def splay
    return 0 unless Puppet[:splay]

    rand(Integer(Puppet[:splaylimit]) + 1).tap do |time|
      Puppet.info "Sleeping for #{time} seconds (splay is enabled)"
    end
  end
end

