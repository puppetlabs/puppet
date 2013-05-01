require 'puppet/network/http'
require 'puppet/util/pidlock'
require 'puppet/network/http/webrick'

#
# @api private
class Puppet::Network::Server
  attr_reader :address, :port

  # TODO: does anything actually call this?  It seems like it's a duplicate of
  # the code in Puppet::Daemon, but that it's not actually called anywhere.

  # Put the daemon into the background.
  def daemonize
    if pid = fork
      Process.detach(pid)
      exit(0)
    end

    # Get rid of console logging
    Puppet::Util::Log.close(:console)

    Process.setsid
    Dir.chdir("/")
  end

  def close_streams()
    Puppet::Daemon.close_streams()
  end

  # Create a pidfile for our daemon, so we can be stopped and others
  # don't try to start.
  def create_pidfile
    Puppet::Util.synchronize_on(Puppet.run_mode.name,Sync::EX) do
      raise "Could not create PID file: #{pidfile}" unless Puppet::Util::Pidlock.new(pidfile).lock
    end
  end

  # Remove the pid file for our daemon.
  def remove_pidfile
    Puppet::Util.synchronize_on(Puppet.run_mode.name,Sync::EX) do
      Puppet::Util::Pidlock.new(pidfile).unlock
    end
  end

  # Provide the path to our pidfile.
  def pidfile
    Puppet[:pidfile]
  end

  def initialize(address, port)
    @port = port
    @address = address
    @http_server = Puppet::Network::HTTP::WEBrick.new

    @listening = false

    # Make sure we have all of the directories we need to function.
    Puppet.settings.use(:main, :ssl, :application)
  end

  def listening?
    @listening
  end

  def listen
    raise "Cannot listen -- already listening." if listening?
    @listening = true
    @http_server.listen(address, port)
  end

  def unlisten
    raise "Cannot unlisten -- not currently listening." unless listening?
    @http_server.unlisten
    @listening = false
  end

  def start
    create_pidfile
    close_streams if Puppet[:daemonize]
    listen
  end

  def stop
    unlisten
    remove_pidfile
  end

  def wait_for_shutdown
    @http_server.wait_for_shutdown
  end
end
