require 'puppet/application'
require 'puppet/configurer'
require 'puppet/util/profiler/aggregate'

class Puppet::Application::Apply < Puppet::Application
  require 'puppet/util/splayer'
  include Puppet::Util::Splayer

  option("--debug","-d")
  option("--execute EXECUTE","-e") do |arg|
    options[:code] = arg
  end
  option("--loadclasses","-L")
  option("--test","-t")
  option("--verbose","-v")
  option("--use-nodes")
  option("--detailed-exitcodes")

  option("--write-catalog-summary")

  option("--catalog catalog",  "-c catalog") do |arg|
    options[:catalog] = arg
  end

  option("--logdest LOGDEST", "-l") do |arg|
    handle_logdest_arg(arg)
  end

  option("--parseonly") do |args|
    puts "--parseonly has been removed. Please use 'puppet parser validate <manifest>'"
    exit 1
  end

  def summary
    _("Apply Puppet manifests locally")
  end

  def help
    <<-HELP

puppet-apply(8) -- #{summary}
========

SYNOPSIS
--------
Applies a standalone Puppet manifest to the local system.


USAGE
-----
puppet apply [-h|--help] [-V|--version] [-d|--debug] [-v|--verbose]
  [-e|--execute] [--detailed-exitcodes] [-L|--loadclasses]
  [-l|--logdest syslog|eventlog|<ABS FILEPATH>|console] [--noop]
  [--catalog <catalog>] [--write-catalog-summary] <file>


DESCRIPTION
-----------
This is the standalone puppet execution tool; use it to apply
individual manifests.

When provided with a modulepath, via command line or config file, puppet
apply can effectively mimic the catalog that would be served by puppet
master with access to the same modules, although there are some subtle
differences. When combined with scheduling and an automated system for
pushing manifests, this can be used to implement a serverless Puppet
site.

Most users should use 'puppet agent' and 'puppet master' for site-wide
manifests.


OPTIONS
-------
Note that any setting that's valid in the configuration
file is also a valid long argument. For example, 'tags' is a
valid setting, so you can specify '--tags <class>,<tag>'
as an argument.

See the configuration file documentation at
https://docs.puppet.com/puppet/latest/reference/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet with
'--genconfig'.

* --debug:
  Enable full debugging.

* --detailed-exitcodes:
  Provide extra information about the run via exit codes. If enabled, 'puppet
  apply' will use the following exit codes:

  0: The run succeeded with no changes or failures; the system was already in
  the desired state.

  1: The run failed.

  2: The run succeeded, and some resources were changed.

  4: The run succeeded, and some resources failed.

  6: The run succeeded, and included both changes and failures.

* --help:
  Print this help message

* --loadclasses:
  Load any stored classes. 'puppet agent' caches configured classes
  (usually at /etc/puppetlabs/puppet/classes.txt), and setting this option causes
  all of those classes to be set in your puppet manifest.

* --logdest:
  Where to send log messages. Choose between 'syslog' (the POSIX syslog
  service), 'eventlog' (the Windows Event Log), 'console', or the path to a log
  file. Defaults to 'console'.

  A path ending with '.json' will receive structured output in JSON format. The
  log file will not have an ending ']' automatically written to it due to the
  appending nature of logging. It must be appended manually to make the content
  valid JSON.

* --noop:
  Use 'noop' mode where Puppet runs in a no-op or dry-run mode. This
  is useful for seeing what changes Puppet will make without actually
  executing the changes.

* --execute:
  Execute a specific piece of Puppet code

* --test:
  Enable the most common options used for testing. These are 'verbose',
  'detailed-exitcodes' and 'show_diff'.

* --verbose:
  Print extra information.

* --catalog:
  Apply a JSON catalog (such as one generated with 'puppet master --compile'). You can
  either specify a JSON file or pipe in JSON from standard input.

* --write-catalog-summary
  After compiling the catalog saves the resource list and classes list to the node
  in the state directory named classes.txt and resources.txt

EXAMPLE
-------
    $ puppet apply -l /tmp/manifest.log manifest.pp
    $ puppet apply --modulepath=/root/dev/modules -e "include ntpd::server"
    $ puppet apply --catalog catalog.json


AUTHOR
------
Luke Kanies


COPYRIGHT
---------
Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0 License

    HELP
  end

  def app_defaults
    super.merge({
      :default_file_terminus => :file_server,
    })
  end

  def run_command
    if options[:catalog]
      apply
    else
      main
    end
  end

  def apply
    if options[:catalog] == "-"
      text = $stdin.read
    else
      text = Puppet::FileSystem.read(options[:catalog], :encoding => 'utf-8')
    end
    env = Puppet.lookup(:environments).get(Puppet[:environment])
    Puppet.override(:current_environment => env, :loaders => Puppet::Pops::Loaders.new(env)) do
      catalog = read_catalog(text)
      apply_catalog(catalog)
    end
  end

  def main
    # Set our code or file to use.
    if options[:code] or command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      manifest = command_line.args.shift
      raise _("Could not find file %{manifest}") % { manifest: manifest } unless Puppet::FileSystem.exist?(manifest)
      Puppet.warning(_("Only one file can be applied per run.  Skipping %{files}") % { files: command_line.args.join(', ') }) if command_line.args.size > 0
    end

    # splay if needed
    splay

    unless Puppet[:node_name_fact].empty?
      # Collect our facts.
      unless facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
        raise _("Could not find facts for %{node}") % { node: Puppet[:node_name_value] }
      end

      Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
      facts.name = Puppet[:node_name_value]
    end

    # Find our Node
    unless node = Puppet::Node.indirection.find(Puppet[:node_name_value])
      raise _("Could not find node %{node}") % { node: Puppet[:node_name_value] }
    end

    configured_environment = node.environment || Puppet.lookup(:current_environment)

    apply_environment = manifest ?
      configured_environment.override_with(:manifest => manifest) :
      configured_environment

    # Modify the node descriptor to use the special apply_environment.
    # It is based on the actual environment from the node, or the locally
    # configured environment if the node does not specify one.
    # If a manifest file is passed on the command line, it overrides
    # the :manifest setting of the apply_environment.
    node.environment = apply_environment

    #TRANSLATORS "puppet apply" is a program command and should not be translated
    Puppet.override({:current_environment => apply_environment}, _("For puppet apply")) do
      # Merge in the facts.
      node.merge(facts.values) if facts

      # Add server facts so $server_facts[environment] exists when doing a puppet apply
      node.add_server_facts({})

      # Allow users to load the classes that puppet agent creates.
      if options[:loadclasses]
        file = Puppet[:classfile]
        if Puppet::FileSystem.exist?(file)
          unless FileTest.readable?(file)
            $stderr.puts _("%{file} is not readable") % { file: file }
            exit(63)
          end
          node.classes = Puppet::FileSystem.read(file, :encoding => 'utf-8').split(/[\s\n]+/)
        end
      end

      begin
        # Compile the catalog
        starttime = Time.now

        # When compiling, the compiler traps and logs certain errors
        # Those that do not lead to an immediate exit are caught by the general
        # rule and gets logged.
        #
        catalog =
        begin
          Puppet::Resource::Catalog.indirection.find(node.name, :use_node => node)
        rescue Puppet::ParseErrorWithIssue, Puppet::Error
          # already logged and handled by the compiler for these two cases
          exit(1)
        end

        # Translate it to a RAL catalog
        catalog = catalog.to_ral

        catalog.finalize

        catalog.retrieval_duration = Time.now - starttime

        if options[:write_catalog_summary]
          catalog.write_class_file
          catalog.write_resource_file
        end

        exit_status = Puppet.override(:loaders => Puppet::Pops::Loaders.new(apply_environment)) { apply_catalog(catalog) }

        if not exit_status
          exit(1)
        elsif options[:detailed_exitcodes] then
          exit(exit_status)
        else
          exit(0)
        end
      rescue => detail
        Puppet.log_exception(detail)
        exit(1)
      end
    end

  ensure
    if @profiler
      Puppet::Util::Profiler.remove_profiler(@profiler)
      @profiler.shutdown
    end
  end

  # Enable all of the most common test options.
  def setup_test
    Puppet.settings.handlearg("--no-splay")
    Puppet.settings.handlearg("--show_diff")
    options[:verbose] = true
    options[:detailed_exitcodes] = true
  end

  def setup
    setup_test if options[:test]

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet::Util::Log.newdestination(:console) unless options[:setdest]

    Signal.trap(:INT) do
      $stderr.puts _("Exiting")
      exit(1)
    end

    Puppet.settings.use :main, :agent, :ssl


    if Puppet[:noop]
      Puppet::Resource::Catalog.indirection.cache_class = nil
    elsif Puppet[:catalog_cache_terminus]
      Puppet::Resource::Catalog.indirection.cache_class = Puppet[:catalog_cache_terminus]
    end

    # we want the last report to be persisted locally
    Puppet::Transaction::Report.indirection.cache_class = :yaml

    set_log_level

    if Puppet[:profile]
      @profiler = Puppet::Util::Profiler.add_profiler(Puppet::Util::Profiler::Aggregate.new(Puppet.method(:info), "apply"))
    end
  end

  private

  def read_catalog(text)
    format = Puppet::Resource::Catalog.default_format
    begin
      catalog = Puppet::Resource::Catalog.convert_from(format, text)
    rescue => detail
      raise Puppet::Error, _("Could not deserialize catalog from %{format}: %{detail}") % { format: format, detail: detail }, detail.backtrace
    end

    catalog.to_ral
  end

  def apply_catalog(catalog)
    configurer = Puppet::Configurer.new
    configurer.run(:catalog => catalog, :pluginsync => false)
  end
end
