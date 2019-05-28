require 'puppet/application'
require 'puppet/configurer'
require 'puppet/util/network_device'

class Puppet::Application::Device < Puppet::Application

  run_mode :agent

  attr_accessor :args, :agent, :host

  def app_defaults
    super.merge({
      :catalog_terminus => :rest,
      :catalog_cache_terminus => :json,
      :node_terminus => :rest,
      :facts_terminus => :network_device,
    })
  end

  def preinit
    # Do an initial trap, so that cancels don't get a stack trace.
    Signal.trap(:INT) do
      $stderr.puts _("Cancelling startup")
      exit(0)
    end

    {
      :apply => nil,
      :waitforcert => nil,
      :detailed_exitcodes => false,
      :verbose => false,
      :debug => false,
      :centrallogs => false,
      :setdest => false,
      :resource => false,
      :facts => false,
      :target => nil,
      :to_yaml => false,
    }.each do |opt,val|
      options[opt] = val
    end

    @args = {}
  end

  option("--centrallogging")
  option("--debug","-d")
  option("--resource","-r")
  option("--facts","-f")
  option("--to_yaml","-y")
  option("--verbose","-v")

  option("--detailed-exitcodes") do |arg|
    options[:detailed_exitcodes] = true
  end

  option("--libdir LIBDIR") do |arg|
    options[:libdir] = arg
  end

  option("--apply MANIFEST") do |arg|
    options[:apply] = arg.to_s
  end

  option("--logdest DEST", "-l DEST") do |arg|
    handle_logdest_arg(arg)
  end

  option("--waitforcert WAITFORCERT", "-w") do |arg|
    options[:waitforcert] = arg.to_i
  end

  option("--port PORT","-p") do |arg|
    @args[:Port] = arg
  end

  option("--target DEVICE", "-t") do |arg|
    options[:target] = arg.to_s
  end

  def summary
    _("Manage remote network devices")
  end

  def help
      <<-HELP

puppet-device(8) -- #{summary}
========

SYNOPSIS
--------
Retrieves catalogs from the Puppet master and applies them to remote devices.

This subcommand can be run manually; or periodically using cron,
a scheduled task, or a similar tool.


USAGE
-----
  puppet device [-h|--help] [-v|--verbose] [-d|--debug]
                [-l|--logdest syslog|<file>|console] [--detailed-exitcodes]
                [--deviceconfig <file>] [-w|--waitforcert <seconds>]
                [--libdir <directory>]
                [-a|--apply <file>] [-f|--facts] [-r|--resource <type> [name]]
                [-t|--target <device>] [--user=<user>] [-V|--version]


DESCRIPTION
-----------
Devices require a proxy Puppet agent to request certificates, collect facts,
retrieve and apply catalogs, and store reports.


USAGE NOTES
-----------
Devices managed by the puppet-device subcommand on a Puppet agent are
configured in device.conf, which is located at $confdir/device.conf by default,
and is configurable with the $deviceconfig setting.

The device.conf file is an INI-like file, with one section per device:

[<DEVICE_CERTNAME>]
type <TYPE>
url <URL>
debug

The section name specifies the certname of the device.

The values for the type and url properties are specific to each type of device.

The optional debug property specifies transport-level debugging,
and is limited to telnet and ssh transports.

See https://puppet.com/docs/puppet/latest/config_file_device.html for details.


OPTIONS
-------
Note that any setting that's valid in the configuration file is also a valid
long argument. For example, 'server' is a valid configuration parameter, so
you can specify '--server <servername>' as an argument.

* --help, -h:
  Print this help message

* --verbose, -v:
  Turn on verbose reporting.

* --debug, -d:
  Enable full debugging.

* --logdest, -l:
  Where to send log messages. Choose between 'syslog' (the POSIX syslog
  service), 'console', or the path to a log file. If debugging or verbosity is
  enabled, this defaults to 'console'. Otherwise, it defaults to 'syslog'.

  A path ending with '.json' will receive structured output in JSON format. The
  log file will not have an ending ']' automatically written to it due to the
  appending nature of logging. It must be appended manually to make the content
  valid JSON.

* --detailed-exitcodes:
  Provide transaction information via exit codes. If this is enabled, an exit
  code of '1' means at least one device had a compile failure, an exit code of
  '2' means at least one device had resource changes, and an exit code of '4'
  means at least one device had resource failures. Exit codes of '3', '5', '6',
  or '7' means that a bitwise combination of the preceding exit codes happened.

* --deviceconfig:
  Path to the device config file for puppet device.
  Default: $confdir/device.conf

* --waitforcert, -w:
  This option only matters for targets that do not yet have certificates
  and it is enabled by default, with a value of 120 (seconds).  This causes
  +puppet device+ to poll the server every 2 minutes and ask it to sign a
  certificate request.  This is useful for the initial setup of a target.
  You can turn off waiting for certificates by specifying a time of 0.

* --libdir:
  Override the per-device libdir with a local directory. Specifying a libdir also
  disables pluginsync. This is useful for testing.

* --apply:
  Apply a manifest against a remote target. Target must be specified.

* --facts:
  Displays the facts of a remote target. Target must be specified.

* --resource:
  Displays a resource state as Puppet code, roughly equivalent to
  `puppet resource`.  Can be filterd by title. Requires --target be specified.

* --target:
  Target a specific device/certificate in the device.conf. Doing so will perform a
  device run against only that device/certificate.

* --to_yaml:
  Output found resources in yaml format, suitable to use with Hiera and
  create_resources.

* --user:
  The user to run as.


EXAMPLE
-------
      $ puppet device --target remotehost --verbose

AUTHOR
------
Brice Figureau


COPYRIGHT
---------
Copyright (c) 2011-2018 Puppet Inc., LLC
Licensed under the Apache 2.0 License
      HELP
  end


  def main
    if options[:resource] and !options[:target]
      raise _("resource command requires target")
    end
    if options[:facts] and !options[:target]
      raise _("facts command requires target")
    end
    unless options[:apply].nil?
      raise _("missing argument: --target is required when using --apply") if options[:target].nil?
      raise _("%{file} does not exist, cannot apply") % { file: options[:apply] } unless File.file?(options[:apply])
    end
    libdir = Puppet[:libdir]
    vardir = Puppet[:vardir]
    confdir = Puppet[:confdir]
    certname = Puppet[:certname]

    env = Puppet::Node::Environment.remote(Puppet[:environment])
    returns = Puppet.override(:current_environment => env, :loaders => Puppet::Pops::Loaders.new(env)) do
      # find device list
      require 'puppet/util/network_device/config'
      devices = Puppet::Util::NetworkDevice::Config.devices.dup
      if options[:target]
        devices.select! { |key, value| key == options[:target] }
      end
      if devices.empty?
        if options[:target]
          raise _("Target device / certificate '%{target}' not found in %{config}") % { target: options[:target], config: Puppet[:deviceconfig] }
        else
          Puppet.err _("No device found in %{config}") % { config: Puppet[:deviceconfig] }
          exit(1)
        end
      end
      devices.collect do |devicename,device|
        pool = Puppet::Network::HTTP::Pool.new(Puppet[:http_keepalive_timeout])
        Puppet.override(:http_pool => pool) do
          # TODO when we drop support for ruby < 2.5 we can remove the extra block here
          begin
            device_url = URI.parse(device.url)
            # Handle nil scheme & port
            scheme = "#{device_url.scheme}://" if device_url.scheme
            port = ":#{device_url.port}" if device_url.port

            # override local $vardir and $certname
            Puppet[:confdir] = ::File.join(Puppet[:devicedir], device.name)
            Puppet[:libdir] = options[:libdir] || ::File.join(Puppet[:devicedir], device.name, 'lib')
            Puppet[:vardir] = ::File.join(Puppet[:devicedir], device.name)
            Puppet[:certname] = device.name
            ssl_host = nil

            unless options[:resource] || options[:facts] || options[:apply]
              # this will reload and recompute default settings and create device-specific sub vardir
              Puppet.settings.use :main, :agent, :ssl

              # Since it's too complicated to fix properly in the default settings, we workaround for PUP-9642 here.
              # See https://github.com/puppetlabs/puppet/pull/7483#issuecomment-483455997 for details.
              # This has to happen after `settings.use` above, so the directory is created and before `setup_host` below, where the SSL
              # routines would fail with access errors
              if Puppet.features.root? && !Puppet::Util::Platform.windows?
                user = Puppet::Type.type(:user).new(name: Puppet[:user]).exists? ? Puppet[:user] : nil
                group = Puppet::Type.type(:group).new(name: Puppet[:group]).exists? ? Puppet[:group] : nil
                Puppet.debug("Fixing perms for #{user}:#{group} on #{Puppet[:confdir]}")
                FileUtils.chown(user, group, Puppet[:confdir]) if user || group
              end

              # ask for a ssl cert if needed, and setup the ssl system for this device.
              ssl_host = setup_host(device.name)

              unless options[:libdir]
                Puppet.override(ssl_host: ssl_host) do
                  Puppet::Configurer::PluginHandler.new.download_plugins(env) if Puppet::Configurer.should_pluginsync?
                end
              end
            end

            # this inits the device singleton, so that the facts terminus
            # and the various network_device provider can use it
            Puppet::Util::NetworkDevice.init(device)

            if options[:resource]
              type, name = parse_args(command_line.args)
              Puppet.info _("retrieving resource: %{resource} from %{target} at %{scheme}%{url_host}%{port}%{url_path}") % { resource: type, target: device.name, scheme: scheme, url_host: device_url.host, port: port, url_path: device_url.path }
              resources = find_resources(type, name)
              if options[:to_yaml]
                text = resources.map do |resource|
                  resource.prune_parameters(:parameters_to_include => @extra_params).to_hierayaml.force_encoding(Encoding.default_external)
                end.join("\n")
                text.prepend("#{type.downcase}:\n")
              else
                text = resources.map do |resource|
                  resource.prune_parameters(:parameters_to_include => @extra_params).to_manifest.force_encoding(Encoding.default_external)
                end.join("\n")
              end
              (puts text)
              0
            elsif options[:facts]
              Puppet.info _("retrieving facts from %{target} at %{scheme}%{url_host}%{port}%{url_path}") % { resource: type, target: device.name, scheme: scheme, url_host: device_url.host, port: port, url_path: device_url.path }
              remote_facts = Puppet::Node::Facts.indirection.find(name, :environment => env)
              # Give a proper name to the facts
              remote_facts.name = remote_facts.values['clientcert']
              renderer = Puppet::Network::FormatHandler.format(:console)
              puts renderer.render(remote_facts)
              0
            elsif options[:apply]
              # avoid reporting to server
              Puppet::Transaction::Report.indirection.terminus_class = :yaml
              Puppet::Resource::Catalog.indirection.cache_class = nil

              require 'puppet/application/apply'
              begin
                Puppet[:node_terminus] = :plain
                Puppet[:catalog_terminus] = :compiler
                Puppet[:catalog_cache_terminus] = nil
                Puppet[:facts_terminus] = :network_device
                Puppet.override(:network_device => true) do
                  Puppet::Application::Apply.new(Puppet::Util::CommandLine.new('puppet', ["apply", options[:apply]])).run_command
                end
              end
            else
              Puppet.info _("starting applying configuration to %{target} at %{scheme}%{url_host}%{port}%{url_path}") % { target: device.name, scheme: scheme, url_host: device_url.host, port: port, url_path: device_url.path }

              overrides = {}
              overrides[:ssl_host] = ssl_host if ssl_host
              Puppet.override(overrides) do
                configurer = Puppet::Configurer.new
                configurer.run(:network_device => true, :pluginsync => false)
              end
            end
          rescue => detail
            Puppet.log_exception(detail)
            # If we rescued an error, then we return 1 as the exit code
            1
          ensure
            pool.close
            Puppet[:libdir] = libdir
            Puppet[:vardir] = vardir
            Puppet[:confdir] = confdir
            Puppet[:certname] = certname
            Puppet::SSL::Host.reset
          end
        end
      end
    end

    if ! returns or returns.compact.empty?
      exit(1)
    elsif options[:detailed_exitcodes]
      # Bitwise OR the return codes together, puppet style
      exit(returns.compact.reduce(:|))
    elsif returns.include? 1
      exit(1)
    else
      exit(0)
    end
  end

  def parse_args(args)
    type = args.shift or raise _("You must specify the type to display")
    Puppet::Type.type(type) or raise _("Could not find type %{type}") % { type: type }
    name = args.shift

    [type, name]
  end

  def find_resources(type, name)
    key = [type, name].join('/')

    if name
      [ Puppet::Resource.indirection.find( key ) ]
    else
      Puppet::Resource.indirection.search( key, {} )
    end
  end

  def setup_host(name)
    host = Puppet::SSL::Host.new(name, true)
    waitforcert = options[:waitforcert] || (Puppet[:onetime] ? 0 : Puppet[:waitforcert])
    host.wait_for_cert(waitforcert)
    host
  end

  def setup
    setup_logs

    # setup global device-specific defaults; creates all necessary directories, etc
    Puppet.settings.use :main, :agent, :device, :ssl

    if options[:apply] || options[:facts] || options[:resource]
      Puppet::Util::Log.newdestination(:console)
    else
      args[:Server] = Puppet[:server]
      if options[:centrallogs]
        logdest = args[:Server]

        logdest += ":" + args[:Port] if args.include?(:Port)
        Puppet::Util::Log.newdestination(logdest)
      end

      Puppet::Transaction::Report.indirection.terminus_class = :rest

      if Puppet[:catalog_cache_terminus]
        Puppet::Resource::Catalog.indirection.cache_class = Puppet[:catalog_cache_terminus].intern
      end
    end
  end
end
