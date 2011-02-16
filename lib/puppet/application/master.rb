require 'puppet/application'

class Puppet::Application::Master < Puppet::Application

  should_parse_config
  run_mode :master

  option("--debug", "-d")
  option("--verbose", "-v")

  # internal option, only to be used by ext/rack/config.ru
  option("--rack")

  option("--compile host",  "-c host") do |arg|
    options[:node] = arg
  end

  option("--logdest DEST",  "-l DEST") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:setdest] = true
    rescue => detail
      puts detail.backtrace if Puppet[:debug]
      $stderr.puts detail.to_s
    end
  end

  def preinit
    Signal.trap(:INT) do
      $stderr.puts "Cancelling startup"
      exit(0)
    end

    # Create this first-off, so we have ARGV
    require 'puppet/daemon'
    @daemon = Puppet::Daemon.new
    @daemon.argv = ARGV.dup
  end

  def run_command
    if options[:node]
      compile
    elsif Puppet[:parseonly]
      parseonly
    else
      main
    end
  end

  def compile
    Puppet::Util::Log.newdestination :console
    raise ArgumentError, "Cannot render compiled catalogs without pson support" unless Puppet.features.pson?
    begin
      unless catalog = Puppet::Resource::Catalog.find(options[:node])
        raise "Could not compile catalog for #{options[:node]}"
      end

      jj catalog.to_resource
    rescue => detail
      $stderr.puts detail
      exit(30)
    end
    exit(0)
  end

  def parseonly
    begin
      Puppet::Node::Environment.new(Puppet[:environment]).known_resource_types
    rescue => detail
      Puppet.err detail
      exit 1
    end
    exit(0)
  end

  def main
    require 'etc'
    require 'puppet/file_serving/content'
    require 'puppet/file_serving/metadata'

    xmlrpc_handlers = [:Status, :FileServer, :Master, :Report, :Filebucket]

    xmlrpc_handlers << :CA if Puppet[:ca]

    # Make sure we've got a localhost ssl cert
    Puppet::SSL::Host.localhost

    # And now configure our server to *only* hit the CA for data, because that's
    # all it will have write access to.
    Puppet::SSL::Host.ca_location = :only if Puppet::SSL::CertificateAuthority.ca?

    if Puppet.features.root?
      begin
        Puppet::Util.chuser
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        $stderr.puts "Could not change user to #{Puppet[:user]}: #{detail}"
        exit(39)
      end
    end

    unless options[:rack]
      require 'puppet/network/server'
      @daemon.server = Puppet::Network::Server.new(:xmlrpc_handlers => xmlrpc_handlers)
      @daemon.daemonize if Puppet[:daemonize]
    else
      require 'puppet/network/http/rack'
      @app = Puppet::Network::HTTP::Rack.new(:xmlrpc_handlers => xmlrpc_handlers, :protocols => [:rest, :xmlrpc])
    end

    Puppet.notice "Starting Puppet master version #{Puppet.version}"

    unless options[:rack]
      @daemon.start
    else
      return @app
    end
  end

  def setup
    # Handle the logging settings.
    if options[:debug] or options[:verbose]
      if options[:debug]
        Puppet::Util::Log.level = :debug
      else
        Puppet::Util::Log.level = :info
      end

      unless Puppet[:daemonize] or options[:rack]
        Puppet::Util::Log.newdestination(:console)
        options[:setdest] = true
      end
    end

    Puppet::Util::Log.newdestination(:syslog) unless options[:setdest]

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet.settings.use :main, :master, :ssl

    # Cache our nodes in yaml.  Currently not configurable.
    Puppet::Node.cache_class = :yaml

    # Configure all of the SSL stuff.
    if Puppet::SSL::CertificateAuthority.ca?
      Puppet::SSL::Host.ca_location = :local
      Puppet.settings.use :ca
      Puppet::SSL::CertificateAuthority.instance
    else
      Puppet::SSL::Host.ca_location = :none
    end
  end
end
