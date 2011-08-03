require 'puppet/application'

class Puppet::Application::Agent < Puppet::Application

  should_parse_config
  run_mode :agent

  attr_accessor :args, :agent, :daemon, :host

  def preinit
    # Do an initial trap, so that cancels don't get a stack trace.
    Signal.trap(:INT) do
      $stderr.puts "Cancelling startup"
      exit(0)
    end

    {
      :waitforcert => nil,
      :detailed_exitcodes => false,
      :verbose => false,
      :debug => false,
      :centrallogs => false,
      :setdest => false,
      :enable => false,
      :disable => false,
      :client => true,
      :fqdn => nil,
      :serve => [],
      :digest => :MD5,
      :fingerprint => false,
    }.each do |opt,val|
      options[opt] = val
    end

    @args = {}
    require 'puppet/daemon'
    @daemon = Puppet::Daemon.new
    @daemon.argv = ARGV.dup
  end

  option("--centrallogging")
  option("--disable")
  option("--enable")
  option("--debug","-d")
  option("--fqdn FQDN","-f")
  option("--test","-t")
  option("--verbose","-v")

  option("--fingerprint")
  option("--digest DIGEST")

  option("--serve HANDLER", "-s") do |arg|
    if Puppet::Network::Handler.handler(arg)
      options[:serve] << arg.to_sym
    else
      raise "Could not find handler for #{arg}"
    end
  end

  option("--no-client") do |arg|
    options[:client] = false
  end

  option("--detailed-exitcodes") do |arg|
    options[:detailed_exitcodes] = true
  end

  option("--logdest DEST", "-l DEST") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:setdest] = true
    rescue => detail
      puts detail.backtrace if Puppet[:debug]
      $stderr.puts detail.to_s
    end
  end

  option("--waitforcert WAITFORCERT", "-w") do |arg|
    options[:waitforcert] = arg.to_i
  end

  option("--port PORT","-p") do |arg|
    @args[:Port] = arg
  end

  def help
    <<-HELP

puppet-agent(8) -- The puppet agent daemon
========

SYNOPSIS
--------
Retrieves the client configuration from the puppet master and applies it to
the local host.

This service may be run as a daemon, run periodically using cron (or something
similar), or run interactively for testing purposes.


USAGE
-----
puppet agent  [-D|--daemonize|--no-daemonize] [-d|--debug]
  [--detailed-exitcodes] [--disable] [--enable] [-h|--help]
  [--certname <host name>] [-l|--logdest syslog|<file>|console]
  [-o|--onetime] [--serve <handler>] [-t|--test] [--noop]
  [--digest <digest>] [--fingerprint] [-V|--version]
  [-v|--verbose] [-w|--waitforcert <seconds>]


DESCRIPTION
-----------
This is the main puppet client. Its job is to retrieve the local
machine's configuration from a remote server and apply it. In order to
successfully communicate with the remote server, the client must have a
certificate signed by a certificate authority that the server trusts;
the recommended method for this, at the moment, is to run a certificate
authority as part of the puppet server (which is the default). The
client will connect and request a signed certificate, and will continue
connecting until it receives one.

Once the client has a signed certificate, it will retrieve its
configuration and apply it.


USAGE NOTES
-----------
'puppet agent' does its best to find a compromise between interactive
use and daemon use. Run with no arguments and no configuration, it will
go into the background, attempt to get a signed certificate, and retrieve
and apply its configuration every 30 minutes.

Some flags are meant specifically for interactive use -- in particular,
'test', 'tags' or 'fingerprint' are useful. 'test' enables verbose
logging, causes the daemon to stay in the foreground, exits if the
server's configuration is invalid (this happens if, for instance, you've
left a syntax error on the server), and exits after running the
configuration once (rather than hanging around as a long-running
process).

'tags' allows you to specify what portions of a configuration you want
to apply. Puppet elements are tagged with all of the class or definition
names that contain them, and you can use the 'tags' flag to specify one
of these names, causing only configuration elements contained within
that class or definition to be applied. This is very useful when you are
testing new configurations -- for instance, if you are just starting to
manage 'ntpd', you would put all of the new elements into an 'ntpd'
class, and call puppet with '--tags ntpd', which would only apply that
small portion of the configuration during your testing, rather than
applying the whole thing.

'fingerprint' is a one-time flag. In this mode 'puppet agent' will run
once and display on the console (and in the log) the current certificate
(or certificate request) fingerprint. Providing the '--digest' option
allows to use a different digest algorithm to generate the fingerprint.
The main use is to verify that before signing a certificate request on
the master, the certificate request the master received is the same as
the one the client sent (to prevent against man-in-the-middle attacks
when signing certificates).


OPTIONS
-------
Note that any configuration parameter that's valid in the configuration
file is also a valid long argument. For example, 'server' is a valid
configuration parameter, so you can specify '--server <servername>' as
an argument.

See the configuration file documentation at
http://docs.puppetlabs.com/references/stable/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet agent with
'--genconfig'.

* --daemonize:
  Send the process into the background. This is the default.

* --no-daemonize:
  Do not send the process into the background.

* --debug:
  Enable full debugging.

* --digest:
  Change the certificate fingerprinting digest algorithm. The default is
  MD5. Valid values depends on the version of OpenSSL installed, but
  should always at least contain MD5, MD2, SHA1 and SHA256.

* --detailed-exitcodes:
  Provide transaction information via exit codes. If this is enabled, an exit
  code of '2' means there were changes, an exit code of '4' means there were
  failures during the transaction, and an exit code of '6' means there were both
  changes and failures.

* --disable:
  Disable working on the local system. This puts a lock file in place,
  causing 'puppet agent' not to work on the system until the lock file
  is removed. This is useful if you are testing a configuration and do
  not want the central configuration to override the local state until
  everything is tested and committed.

  'puppet agent' uses the same lock file while it is running, so no more
  than one 'puppet agent' process is working at a time.

  'puppet agent' exits after executing this.

* --enable:
  Enable working on the local system. This removes any lock file,
  causing 'puppet agent' to start managing the local system again
  (although it will continue to use its normal scheduling, so it might
  not start for another half hour).

  'puppet agent' exits after executing this.

* --certname:
  Set the certname (unique ID) of the client. The master reads this
  unique identifying string, which is usually set to the node's
  fully-qualified domain name, to determine which configurations the
  node will receive. Use this option to debug setup problems or
  implement unusual node identification schemes.

* --help:
  Print this help message

* --logdest:
  Where to send messages. Choose between syslog, the console, and a log
  file. Defaults to sending messages to syslog, or the console if
  debugging or verbosity is enabled.

* --no-client:
  Do not create a config client. This will cause the daemon to run
  without ever checking for its configuration automatically, and only
  makes sense

* --onetime:
  Run the configuration once. Runs a single (normally daemonized) Puppet
  run. Useful for interactively running puppet agent when used in
  conjunction with the --no-daemonize option.

* --fingerprint:
  Display the current certificate or certificate signing request
  fingerprint and then exit. Use the '--digest' option to change the
  digest algorithm used.

* --serve:
  Start another type of server. By default, 'puppet agent' will start a
  service handler that allows authenticated and authorized remote nodes
  to trigger the configuration to be pulled down and applied. You can
  specify any handler here that does not require configuration, e.g.,
  filebucket, ca, or resource. The handlers are in
  'lib/puppet/network/handler', and the names must match exactly, both
  in the call to 'serve' and in 'namespaceauth.conf'.

* --test:
  Enable the most common options used for testing. These are 'onetime',
  'verbose', 'ignorecache', 'no-daemonize', 'no-usecacheonfailure',
  'detailed-exit-codes', 'no-splay', and 'show_diff'.

* --noop:
  Use 'noop' mode where the daemon runs in a no-op or dry-run mode. This
  is useful for seeing what changes Puppet will make without actually
  executing the changes.

* --verbose:
  Turn on verbose reporting.

* --version:
  Print the puppet version number and exit.

* --waitforcert:
  This option only matters for daemons that do not yet have certificates
  and it is enabled by default, with a value of 120 (seconds). This
  causes 'puppet agent' to connect to the server every 2 minutes and ask
  it to sign a certificate request. This is useful for the initial setup
  of a puppet client. You can turn off waiting for certificates by
  specifying a time of 0.


EXAMPLE
-------
    $ puppet agent --server puppet.domain.com


DIAGNOSTICS
-----------

Puppet agent accepts the following signals:

* SIGHUP:
  Restart the puppet agent daemon.
* SIGINT and SIGTERM:
  Shut down the puppet agent daemon.
* SIGUSR1: 
  Immediately retrieve and apply configurations from the puppet master.

AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Labs, LLC Licensed under the Apache 2.0 License

    HELP
  end

  def run_command
    return fingerprint if options[:fingerprint]
    return onetime if Puppet[:onetime]
    main
  end

  def fingerprint
    unless cert = host.certificate || host.certificate_request
      $stderr.puts "Fingerprint asked but no certificate nor certificate request have yet been issued"
      exit(1)
      return
    end
    unless fingerprint = cert.fingerprint(options[:digest])
      raise ArgumentError, "Could not get fingerprint for digest '#{options[:digest]}'"
    end
    puts fingerprint
  end

  def onetime
    unless options[:client]
      $stderr.puts "onetime is specified but there is no client"
      exit(43)
      return
    end

    @daemon.set_signal_traps

    begin
      report = @agent.run
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err detail.to_s
    end

    if not report
      exit(1)
    elsif options[:detailed_exitcodes] then
      exit(report.exit_status)
    else
      exit(0)
    end
  end

  def main
    Puppet.notice "Starting Puppet client version #{Puppet.version}"

    @daemon.start
  end

  # Enable all of the most common test options.
  def setup_test
    Puppet.settings.handlearg("--ignorecache")
    Puppet.settings.handlearg("--no-usecacheonfailure")
    Puppet.settings.handlearg("--no-splay")
    Puppet.settings.handlearg("--show_diff")
    Puppet.settings.handlearg("--no-daemonize")
    options[:verbose] = true
    Puppet[:onetime] = true
    options[:detailed_exitcodes] = true
  end

  # Handle the logging settings.
  def setup_logs
    if options[:debug] or options[:verbose]
      Puppet::Util::Log.newdestination(:console)
      if options[:debug]
        Puppet::Util::Log.level = :debug
      else
        Puppet::Util::Log.level = :info
      end
    end

    Puppet::Util::Log.newdestination(:syslog) unless options[:setdest]
  end

  def enable_disable_client(agent)
    if options[:enable]
      agent.enable
    elsif options[:disable]
      agent.disable
    end
    exit(0)
  end

  def setup_listen
    unless FileTest.exists?(Puppet[:rest_authconfig])
      Puppet.err "Will not start without authorization file #{Puppet[:rest_authconfig]}"
      exit(14)
    end

    handlers = nil

    if options[:serve].empty?
      handlers = [:Runner]
    else
      handlers = options[:serve]
    end

    require 'puppet/network/server'
    # No REST handlers yet.
    server = Puppet::Network::Server.new(:xmlrpc_handlers => handlers, :port => Puppet[:puppetport])

    @daemon.server = server
  end

  def setup_host
    @host = Puppet::SSL::Host.new
    waitforcert = options[:waitforcert] || (Puppet[:onetime] ? 0 : 120)
    cert = @host.wait_for_cert(waitforcert) unless options[:fingerprint]
  end

  def setup
    setup_test if options[:test]

    setup_logs

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    # If noop is set, then also enable diffs
    Puppet[:show_diff] = true if Puppet[:noop]

    args[:Server] = Puppet[:server]
    if options[:fqdn]
      args[:FQDN] = options[:fqdn]
      Puppet[:certname] = options[:fqdn]
    end

    if options[:centrallogs]
      logdest = args[:Server]

      logdest += ":" + args[:Port] if args.include?(:Port)
      Puppet::Util::Log.newdestination(logdest)
    end

    Puppet.settings.use :main, :agent, :ssl

    # Always ignoreimport for agent. It really shouldn't even try to import,
    # but this is just a temporary band-aid.
    Puppet[:ignoreimport] = true

    # We need to specify a ca location for all of the SSL-related i
    # indirected classes to work; in fingerprint mode we just need
    # access to the local files and we don't need a ca.
    Puppet::SSL::Host.ca_location = options[:fingerprint] ? :none : :remote

    Puppet::Transaction::Report.indirection.terminus_class = :rest
    # we want the last report to be persisted locally
    Puppet::Transaction::Report.indirection.cache_class = :yaml

    # Override the default; puppetd needs this, usually.
    # You can still override this on the command-line with, e.g., :compiler.
    Puppet[:catalog_terminus] = :rest

    # Override the default.
    Puppet[:facts_terminus] = :facter

    Puppet::Resource::Catalog.indirection.cache_class = :yaml

    # We need tomake the client either way, we just don't start it
    # if --no-client is set.
    require 'puppet/agent'
    require 'puppet/configurer'
    @agent = Puppet::Agent.new(Puppet::Configurer)

    enable_disable_client(@agent) if options[:enable] or options[:disable]

    @daemon.agent = agent if options[:client]

    # It'd be nice to daemonize later, but we have to daemonize before the
    # waitforcert happens.
    @daemon.daemonize if Puppet[:daemonize]

    setup_host

    @objects = []

    # This has to go after the certs are dealt with.
    if Puppet[:listen]
      unless Puppet[:onetime]
        setup_listen
      else
        Puppet.notice "Ignoring --listen on onetime run"
      end
    end
  end
end
