require 'puppet/application'
require 'puppet/daemon'
require 'puppet/util/pidlock'
require 'puppet/agent'
require 'puppet/configurer'
require 'puppet/ssl/oids'

class Puppet::Application::Agent < Puppet::Application

  run_mode :agent

  def app_defaults
    super.merge({
      :catalog_terminus => :rest,
      :catalog_cache_terminus => :json,
      :node_terminus => :rest,
      :facts_terminus => :facter,
    })
  end

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
      :setdest => false,
      :enable => false,
      :disable => false,
      :fqdn => nil,
      :serve => [],
      :digest => 'SHA256',
      :graph => true,
      :fingerprint => false,
    }.each do |opt,val|
      options[opt] = val
    end

    @argv = ARGV.dup
  end

  option("--disable [MESSAGE]") do |message|
    options[:disable] = true
    options[:disable_message] = message
  end

  option("--enable")
  option("--debug","-d")
  option("--fqdn FQDN","-f")
  option("--test","-t")
  option("--verbose","-v")

  option("--fingerprint")
  option("--digest DIGEST")

  option("--detailed-exitcodes") do |arg|
    options[:detailed_exitcodes] = true
  end

  option("--logdest DEST", "-l DEST") do |arg|
    handle_logdest_arg(arg)
  end

  option("--waitforcert WAITFORCERT", "-w") do |arg|
    options[:waitforcert] = arg.to_i
  end

  def help
    <<-'HELP'

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
puppet agent [--certname <NAME>] [-D|--daemonize|--no-daemonize]
  [-d|--debug] [--detailed-exitcodes] [--digest <DIGEST>] [--disable [MESSAGE]] [--enable]
  [--fingerprint] [-h|--help] [-l|--logdest syslog|eventlog|<FILE>|console]
  [--masterport <PORT>] [--noop] [-o|--onetime] [-t|--test]
  [-v|--verbose] [-V|--version] [-w|--waitforcert <SECONDS>]


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
'test', 'tags' and 'fingerprint' are useful.

'--test' does a single run in the foreground with verbose logging, then exits.
It will also exit if it can't get a valid catalog. The exit code after running
with '--test' is 0 if the catalog was successfully applied, and 1 if the run
either failed or wasn't attempted (due to another run already in progress).

'--tags' allows you to specify what portions of a configuration you want
to apply. Puppet elements are tagged with all of the class or definition
names that contain them, and you can use the 'tags' flag to specify one
of these names, causing only configuration elements contained within
that class or definition to be applied. This is very useful when you are
testing new configurations -- for instance, if you are just starting to
manage 'ntpd', you would put all of the new elements into an 'ntpd'
class, and call puppet with '--tags ntpd', which would only apply that
small portion of the configuration during your testing, rather than
applying the whole thing.

'--fingerprint' is a one-time flag. In this mode 'puppet agent' will run
once and display on the console (and in the log) the current certificate
(or certificate request) fingerprint. Providing the '--digest' option
allows to use a different digest algorithm to generate the fingerprint.
The main use is to verify that before signing a certificate request on
the master, the certificate request the master received is the same as
the one the client sent (to prevent against man-in-the-middle attacks
when signing certificates).


OPTIONS
-------

Note that any Puppet setting that's valid in the configuration file is also a
valid long argument. For example, 'server' is a valid setting, so you can
specify '--server <servername>' as an argument. Boolean settings translate into
'--setting' and '--no-setting' pairs.

See the configuration file documentation at
https://docs.puppetlabs.com/puppet/latest/reference/configuration.html for the
full list of acceptable settings. A commented list of all settings can also be
generated by running puppet agent with '--genconfig'.

* --certname:
  Set the certname (unique ID) of the client. The master reads this
  unique identifying string, which is usually set to the node's
  fully-qualified domain name, to determine which configurations the
  node will receive. Use this option to debug setup problems or
  implement unusual node identification schemes.
  (This is a Puppet setting, and can go in puppet.conf.)

* --daemonize:
  Send the process into the background. This is the default.
  (This is a Puppet setting, and can go in puppet.conf. Note the special 'no-'
  prefix for boolean settings on the command line.)

* --no-daemonize:
  Do not send the process into the background.
  (This is a Puppet setting, and can go in puppet.conf. Note the special 'no-'
  prefix for boolean settings on the command line.)

* --debug:
  Enable full debugging.

* --detailed-exitcodes:
  Provide extra information about the run via exit codes; only works if '--test'
  or '--onetime' is also specified. If enabled, 'puppet agent' will use the
  following exit codes:

  0: The run succeeded with no changes or failures; the system was already in
  the desired state.

  1: The run failed, or wasn't attempted due to another run already in progress.

  2: The run succeeded, and some resources were changed.

  4: The run succeeded, and some resources failed.

  6: The run succeeded, and included both changes and failures.

* --digest:
  Change the certificate fingerprinting digest algorithm. The default is
  SHA256. Valid values depends on the version of OpenSSL installed, but
  will likely contain MD5, MD2, SHA1 and SHA256.

* --disable:
  Disable working on the local system. This puts a lock file in place,
  causing 'puppet agent' not to work on the system until the lock file
  is removed. This is useful if you are testing a configuration and do
  not want the central configuration to override the local state until
  everything is tested and committed.

  Disable can also take an optional message that will be reported by the
  'puppet agent' at the next disabled run.

  'puppet agent' uses the same lock file while it is running, so no more
  than one 'puppet agent' process is working at a time.

  'puppet agent' exits after executing this.

* --enable:
  Enable working on the local system. This removes any lock file,
  causing 'puppet agent' to start managing the local system again
  (although it will continue to use its normal scheduling, so it might
  not start for another half hour).

  'puppet agent' exits after executing this.

* --fingerprint:
  Display the current certificate or certificate signing request
  fingerprint and then exit. Use the '--digest' option to change the
  digest algorithm used.

* --help:
  Print this help message

* --logdest:
  Where to send log messages. Choose between 'syslog' (the POSIX syslog
  service), 'eventlog' (the Windows Event Log), 'console', or the path to a log
  file. If debugging or verbosity is enabled, this defaults to 'console'.
  Otherwise, it defaults to 'syslog' on POSIX systems and 'eventlog' on Windows.

  A path ending with '.json' will receive structured output in JSON format. The
  log file will not have an ending ']' automatically written to it due to the
  appending nature of logging. It must be appended manually to make the content
  valid JSON.

* --masterport:
  The port on which to contact the puppet master.
  (This is a Puppet setting, and can go in puppet.conf.)

* --noop:
  Use 'noop' mode where the daemon runs in a no-op or dry-run mode. This
  is useful for seeing what changes Puppet will make without actually
  executing the changes.
  (This is a Puppet setting, and can go in puppet.conf. Note the special 'no-'
  prefix for boolean settings on the command line.)

* --onetime:
  Run the configuration once. Runs a single (normally daemonized) Puppet
  run. Useful for interactively running puppet agent when used in
  conjunction with the --no-daemonize option.
  (This is a Puppet setting, and can go in puppet.conf. Note the special 'no-'
  prefix for boolean settings on the command line.)

* --test:
  Enable the most common options used for testing. These are 'onetime',
  'verbose', 'no-daemonize', 'no-usecacheonfailure', 'detailed-exitcodes',
  'no-splay', 'show_diff', and 'no-use_cached_catalog'.

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
  (This is a Puppet setting, and can go in puppet.conf. Note the special 'no-'
  prefix for boolean settings on the command line.)


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
* SIGUSR2:
  Close file descriptors for log files and reopen them. Used with logrotate.

AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Labs, LLC Licensed under the Apache 2.0 License

    HELP
  end

  def run_command
    if options[:fingerprint]
      fingerprint
    else
      # It'd be nice to daemonize later, but we have to daemonize before
      # waiting for certificates so that we don't block
      daemon = daemonize_process_when(Puppet[:daemonize])

      # Setup signal traps immediately after daemonization so we clean up the daemon
      daemon.set_signal_traps

      wait_for_certificates

      if Puppet[:onetime]
        onetime(daemon)
      else
        main(daemon)
      end
    end
  end

  def fingerprint
    host = Puppet::SSL::Host.new
    unless cert = host.certificate || host.certificate_request
      $stderr.puts "Fingerprint asked but no certificate nor certificate request have yet been issued"
      exit(1)
      return
    end
    unless digest = cert.digest(options[:digest].to_s)
      raise ArgumentError, "Could not get fingerprint for digest '#{options[:digest]}'"
    end
    puts digest.to_s
  end

  def onetime(daemon)
    begin
      exitstatus = daemon.agent.run
    rescue => detail
      Puppet.log_exception(detail)
    end

    daemon.stop(:exit => false)

    if not exitstatus
      exit(1)
    elsif options[:detailed_exitcodes] then
      exit(exitstatus)
    else
      exit(0)
    end
  end

  def main(daemon)
    Puppet.notice "Starting Puppet client version #{Puppet.version}"
    daemon.start
  end

  # Enable all of the most common test options.
  def setup_test
    Puppet.settings.handlearg("--no-usecacheonfailure")
    Puppet.settings.handlearg("--no-splay")
    Puppet.settings.handlearg("--show_diff")
    Puppet.settings.handlearg("--no-daemonize")
    Puppet.settings.handlearg("--no-use_cached_catalog")
    options[:verbose] = true
    Puppet[:onetime] = true
    options[:detailed_exitcodes] = true
  end

  def setup
    raise ArgumentError, "The puppet agent command does not take parameters" unless command_line.args.empty?

    setup_test if options[:test]

    setup_logs

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet::SSL::Oids.register_puppet_oids

    if options[:fqdn]
      Puppet[:certname] = options[:fqdn]
    end

    Puppet.settings.use :main, :agent, :ssl

    Puppet::Transaction::Report.indirection.terminus_class = :rest
    # we want the last report to be persisted locally
    Puppet::Transaction::Report.indirection.cache_class = :yaml

    if Puppet[:noop]
      Puppet::Resource::Catalog.indirection.cache_class = nil
    elsif Puppet[:catalog_cache_terminus]
      Puppet::Resource::Catalog.indirection.cache_class = Puppet[:catalog_cache_terminus]
    end

    if options[:fingerprint]
      # in fingerprint mode we just need
      # access to the local files and we don't need a ca
      Puppet::SSL::Host.ca_location = :none
    else
      Puppet::SSL::Host.ca_location = :remote
      setup_agent
    end
  end

  private

  def enable_disable_client(agent)
    if options[:enable]
      agent.enable
    elsif options[:disable]
      agent.disable(options[:disable_message] || 'reason not specified')
    end
    exit(0)
  end

  def setup_agent
    agent = Puppet::Agent.new(Puppet::Configurer, (not(Puppet[:onetime])))

    enable_disable_client(agent) if options[:enable] or options[:disable]

    @agent = agent
  end

  def daemonize_process_when(should_daemonize)
    daemon = Puppet::Daemon.new(Puppet::Util::Pidlock.new(Puppet[:pidfile]))
    daemon.argv = @argv
    daemon.agent = @agent

    daemon.daemonize if should_daemonize

    daemon
  end

  def wait_for_certificates
    host = Puppet::SSL::Host.new
    waitforcert = options[:waitforcert] || (Puppet[:onetime] ? 0 : Puppet[:waitforcert])
    host.wait_for_cert(waitforcert)
  end
end
