# frozen_string_literal: true

require_relative '../../puppet/application'
require_relative '../../puppet/configurer'
require_relative '../../puppet/util/profiler/aggregate'

class Puppet::Application::Apply < Puppet::Application
  require_relative '../../puppet/util/splayer'
  include Puppet::Util::Splayer

  option("--debug", "-d")
  option("--execute EXECUTE", "-e") do |arg|
    options[:code] = arg
  end
  option("--loadclasses", "-L")
  option("--test", "-t")
  option("--verbose", "-v")
  option("--use-nodes")
  option("--detailed-exitcodes")

  option("--write-catalog-summary") do |arg|
    Puppet[:write_catalog_summary] = arg
  end

  option("--catalog catalog", "-c catalog") do |arg|
    options[:catalog] = arg
  end

  option("--logdest LOGDEST", "-l") do |arg|
    handle_logdest_arg(arg)
  end

  option("--parseonly") do |_args|
    puts "--parseonly has been removed. Please use 'puppet parser validate <manifest>'"
    exit 1
  end

  def summary
    _("Apply Puppet manifests locally")
  end

  def help
    <<~HELP

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
      Any setting that's valid in the configuration
      file is a valid long argument for puppet apply. For example, 'tags' is a
      valid setting, so you can specify '--tags <class>,<tag>'
      as an argument.

      See the configuration file documentation at
      https://puppet.com/docs/puppet/latest/configuration.html for the
      full list of acceptable parameters. You can generate a commented list of all
      configuration options by running puppet with
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
        Multiple destinations can be set using a comma separated list
        (eg: `/path/file1,console,/path/file2`)"

        A path ending with '.json' will receive structured output in JSON format. The
        log file will not have an ending ']' automatically written to it due to the
        appending nature of logging. It must be appended manually to make the content
        valid JSON.

        A path ending with '.jsonl' will receive structured output in JSON Lines
        format.

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
                  :write_catalog_summary => false
                })
  end

  def run_command
    if options[:catalog]
      apply
    else
      main
    end
  ensure
    if @profiler
      Puppet::Util::Profiler.remove_profiler(@profiler)
      @profiler.shutdown
    end
  end

  def apply
    if options[:catalog] == "-"
      text = $stdin.read
    else
      text = Puppet::FileSystem.read(options[:catalog], :encoding => 'utf-8')
    end
    env = Puppet.lookup(:environments).get(Puppet[:environment])
    Puppet.override(:current_environment => env, :loaders => create_loaders(env)) do
      catalog = read_catalog(text)
      apply_catalog(catalog)
    end
  end

  def main
    # rubocop:disable Layout/ExtraSpacing
    manifest          = get_manifest() # Get either a manifest or nil if apply should use content of Puppet[:code]
    splay                              # splay if needed
    facts             = get_facts()    # facts or nil
    node              = get_node()     # node or error
    apply_environment = get_configured_environment(node, manifest)
    # rubocop:enable Layout/ExtraSpacing

    # TRANSLATORS "puppet apply" is a program command and should not be translated
    Puppet.override({ :current_environment => apply_environment, :loaders => create_loaders(apply_environment) }, _("For puppet apply")) do
      configure_node_facts(node, facts)

      # Allow users to load the classes that puppet agent creates.
      if options[:loadclasses]
        file = Puppet[:classfile]
        if Puppet::FileSystem.exist?(file)
          unless FileTest.readable?(file)
            $stderr.puts _("%{file} is not readable") % { file: file }
            exit(63)
          end
          node.classes = Puppet::FileSystem.read(file, :encoding => 'utf-8').split(/[\s]+/)
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
          rescue Puppet::Error
            # already logged and handled by the compiler, including Puppet::ParseErrorWithIssue
            exit(1)
          end

        # Resolve all deferred values and replace them / mutate the catalog
        Puppet::Pops::Evaluator::DeferredResolver.resolve_and_replace(node.facts, catalog, apply_environment, Puppet[:preprocess_deferred])

        # Translate it to a RAL catalog
        catalog = catalog.to_ral

        catalog.finalize

        catalog.retrieval_duration = Time.now - starttime

        # We accept either the global option `--write_catalog_summary`
        # corresponding to the new setting, or the application option
        # `--write-catalog-summary`. The latter is needed to maintain backwards
        # compatibility.
        #
        # Puppet settings parse global options using PuppetOptionParser, but it
        # only recognizes underscores, not dashes.
        # The base application parses app specific options using ruby's builtin
        # OptionParser. As of ruby 2.4, it will accept either underscores or
        # dashes, but prefer dashes.
        #
        # So if underscores are used, the PuppetOptionParser will parse it and
        # store that in Puppet[:write_catalog_summary]. If dashes are used,
        # OptionParser will parse it, and set Puppet[:write_catalog_summary]. In
        # either case, settings will contain the correct value.
        if Puppet[:write_catalog_summary]
          catalog.write_class_file
          catalog.write_resource_file
        end

        exit_status = apply_catalog(catalog)

        if !exit_status
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

    handle_logdest_arg(Puppet[:logdest])
    Puppet::Util::Log.newdestination(:console) unless options[:setdest]

    Signal.trap(:INT) do
      $stderr.puts _("Exiting")
      exit(1)
    end

    Puppet.settings.use :main, :agent, :ssl

    if Puppet[:catalog_cache_terminus]
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

  def create_loaders(env)
    # Ignore both 'cached_puppet_lib' and pcore resource type loaders
    Puppet::Pops::Loaders.new(env, false, false)
  end

  def read_catalog(text)
    facts = get_facts()
    node = get_node()
    configured_environment = get_configured_environment(node)

    # TRANSLATORS "puppet apply" is a program command and should not be translated
    Puppet.override({ :current_environment => configured_environment }, _("For puppet apply")) do
      configure_node_facts(node, facts)

      # NOTE: Does not set rich_data = true automatically (which would ensure always reading catalog with rich data
      # on (seemingly the right thing to do)), but that would remove the ability to test what happens when a
      # rich catalog is processed without rich_data being turned on.
      format = Puppet::Resource::Catalog.default_format
      begin
        catalog = Puppet::Resource::Catalog.convert_from(format, text)
      rescue => detail
        raise Puppet::Error, _("Could not deserialize catalog from %{format}: %{detail}") % { format: format, detail: detail }, detail.backtrace
      end
      # Resolve all deferred values and replace them / mutate the catalog
      Puppet::Pops::Evaluator::DeferredResolver.resolve_and_replace(node.facts, catalog, configured_environment, Puppet[:preprocess_deferred])

      catalog.to_ral
    end
  end

  def apply_catalog(catalog)
    configurer = Puppet::Configurer.new
    configurer.run(:catalog => catalog, :pluginsync => false)
  end

  # Returns facts or nil
  #
  def get_facts
    facts = nil
    unless Puppet[:node_name_fact].empty?
      # Collect our facts.
      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
      raise _("Could not find facts for %{node}") % { node: Puppet[:node_name_value] } unless facts

      Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
      facts.name = Puppet[:node_name_value]
    end
    facts
  end

  # Returns the node or raises and error if node not found.
  #
  def get_node
    node = Puppet::Node.indirection.find(Puppet[:node_name_value])
    raise _("Could not find node %{node}") % { node: Puppet[:node_name_value] } unless node

    node
  end

  # Returns either a manifest (filename) or nil if apply should use content of Puppet[:code]
  #
  def get_manifest
    manifest = nil
    # Set our code or file to use.
    if options[:code] or command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      manifest = command_line.args.shift
      raise _("Could not find file %{manifest}") % { manifest: manifest } unless Puppet::FileSystem.exist?(manifest)

      Puppet.warning(_("Only one file can be applied per run.  Skipping %{files}") % { files: command_line.args.join(', ') }) if command_line.args.size > 0
    end
    manifest
  end

  # Returns a configured environment, if a manifest is given it overrides what is configured for the environment
  # specified by the node (or the current_environment found in the Puppet context).
  # The node's resolved environment is modified  if needed.
  #
  def get_configured_environment(node, manifest = nil)
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
    apply_environment
  end

  # Mixes the facts into the node, and mixes in server facts
  def configure_node_facts(node, facts)
    node.merge(facts.values) if facts
    # Add server facts so $server_facts[environment] exists when doing a puppet apply
    node.add_server_facts({})
  end
end
