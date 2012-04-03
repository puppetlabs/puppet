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
      # Here we're closing off stdin/stdout/stderr as we go into daemon mode.
      #
      # This is probably not a great way to accomplish it... we are opening them as Files so that
      # we will be able to easily detect that they are pointing at /dev/null later.  It would be
      # nice to at least abstract this into the logging mechanism or somewhere similar.
      #
      # Some known quirks around this:
      #
      # 1. The logging framework sometimes catches errors and tries to fall back to a console log,
      #    which is well-nigh useless if these are redirected to /dev/null (unless we can detect
      #    that condition, but that's still a bit of a hack)
      # 2. It would be preferable to not even attempt to close these until we've gotten far enough
      #    in our bootstrapping that we know for certain that all of the other log destinations
      #    are initialized, so it's safe to close these.  I haven't done that yet because there
      #    are several places where the logs may be initialized, and sometimes there will be
      #    calls to 'chuser' in between them.
      # 3. This implementation does *not* reset STDOUT/STDERR constants (which $stdout.reopen, etc.
      #    *would* do)... so it is possible that some naughty code somewhere could still write
      #    to those, and that's not entirely desirable for daemon mode.
      #
      # This works for now but a lot of this could probably use some thoughtful design work,
      #  adjustment to the bootstrapping order, etc., when someone has time.  --cprice 2012-04-02
      $stdin = File.open("/dev/null")
      $stdout = File.open("/dev/null", "a")
      $stderr = $stdout
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
    #
    # We want to trigger the reparse if 15 seconds passed since the previous
    # wakeup, and the agent run if Puppet[:runinterval] seconds have passed
    # since the previous wakeup.
    #
    # We always want to run the agent on startup, so it was always before now.
    # Because 0 means "continuously run", `to_i` does the right thing when the
    # input is strange or badly formed by returning 0.  Integer will raise,
    # which we don't want, and we want to protect against -1 or below.
    next_agent_run = 0
    agent_run_interval = [Puppet[:runinterval].to_i, 0].max

    # We may not want to reparse; that can be disable.  Fun times.
    next_reparse = 0
    reparse_interval = Puppet[:filetimeout].to_i

    loop do
      now = Time.now.to_i

      # Handle reparsing of configuration files, if desired and required.
      # `reparse` will just check if the action is required, and would be
      # better named `reparse_if_changed` instead.
      if reparse_interval > 0 and now >= next_reparse
        Puppet.settings.reparse

        # The time to the next reparse might have changed, so recalculate
        # now.  That way we react dynamically to reconfiguration.
        reparse_interval = Puppet[:filetimeout].to_i
        next_reparse     = now + reparse_interval

        # We should also recalculate the agent run interval, and adjust the
        # next time it is scheduled to run, just in case.  In the event that
        # we made no change the result will be a zero second adjustment.
        new_run_interval    = [Puppet[:runinterval].to_i, 0].max
        next_agent_run     += agent_run_interval - new_run_interval
        agent_run_interval  = new_run_interval
      end

      # Handle triggering another agent run.  This will block the next check
      # for configuration reparsing, which is a desired and deliberate
      # behaviour.  You should not change that. --daniel 2012-02-21
      if agent and now >= next_agent_run
        agent.run
        next_agent_run = now + agent_run_interval
      end

      # Finally, an interruptable able sleep until the next scheduled event.
      # We also set a default wakeup of "one hour from now", which will
      # recheck everything at a minimum every hour.  Just in case something in
      # the math messes up or something; it should be inexpensive enough to
      # wake once an hour, then go back to sleep after doing nothing, if
      # someone only wants listen mode.
      next_event = now + 60 * 60
      next_event > next_reparse    and next_event = next_reparse
      next_event > next_agent_run  and next_event = next_agent_run

      how_long = next_event - now

      how_long > 0 and select([], [], [], how_long)
    end
  end
end

