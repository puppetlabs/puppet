# frozen_string_literal: true
require_relative '../../puppet/application'
require_relative '../../puppet/configurer'
require_relative '../../puppet/util/profiler/aggregate'
require_relative '../../puppet/parser/script_compiler'

class Puppet::Application::Script < Puppet::Application

  option("--debug","-d")
  option("--execute EXECUTE","-e") do |arg|
    options[:code] = arg
  end
  option("--test","-t")
  option("--verbose","-v")

  option("--logdest LOGDEST", "-l") do |arg|
    handle_logdest_arg(arg)
  end

  def summary
    _("Run a puppet manifests as a script without compiling a catalog")
  end

  def help
    <<-HELP

puppet-script(8) -- #{summary}
========

SYNOPSIS
--------
Runs a puppet language script without compiling a catalog.


USAGE
-----
puppet script [-h|--help] [-V|--version] [-d|--debug] [-v|--verbose]
  [-e|--execute]
  [-l|--logdest syslog|eventlog|<FILE>|console] [--noop]
  <file>


DESCRIPTION
-----------
This is a standalone puppet script runner tool; use it to run puppet code
without compiling a catalog.

When provided with a modulepath, via command line or config file, puppet
script can load functions, types, tasks and plans from modules.

OPTIONS
-------
Note that any setting that's valid in the configuration
file is also a valid long argument. For example, 'environment' is a
valid setting, so you can specify '--environment mytest'
as an argument.

See the configuration file documentation at
https://puppet.com/docs/puppet/latest/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet with
'--genconfig'.

* --debug:
  Enable full debugging.

* --help:
  Print this help message


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
  executing the changes. Applies to tasks only.

* --execute:
  Execute a specific piece of Puppet code

* --verbose:
  Print extra information.

EXAMPLE
-------
    $ puppet script -l /tmp/manifest.log manifest.pp
    $ puppet script --modulepath=/root/dev/modules -e 'notice("hello world")'


AUTHOR
------
Henrik Lindberg


COPYRIGHT
---------
Copyright (c) 2017 Puppet Inc., LLC Licensed under the Apache 2.0 License

    HELP
  end

  def app_defaults
    super.merge({
      :default_file_terminus => :file_server,
    })
  end

  def run_command
    if Puppet.features.bolt?
      Puppet.override(:bolt_executor => Bolt::Executor.new) do
        main
      end
    else
      raise _("Bolt must be installed to use the script application")
    end
  end

  def main
    # The tasks feature is always on
    Puppet[:tasks] = true

    # Set the puppet code or file to use.
    if options[:code] || command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      manifest = command_line.args.shift
      raise _("Could not find file %{manifest}") % { manifest: manifest } unless Puppet::FileSystem.exist?(manifest)

      Puppet.warning(_("Only one file can be used per run. Skipping %{files}") % { files: command_line.args.join(', ') }) if command_line.args.size > 0
    end

    unless Puppet[:node_name_fact].empty?
      # Collect the facts specified for that node
      facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
      raise _("Could not find facts for %{node}") % { node: Puppet[:node_name_value] } unless facts

      Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
      facts.name = Puppet[:node_name_value]
    end

    # Find the Node
    node = Puppet::Node.indirection.find(Puppet[:node_name_value])
    raise _("Could not find node %{node}") % { node: Puppet[:node_name_value] } unless node

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

    # TRANSLATION, the string "For puppet script" is not user facing
    Puppet.override({:current_environment => apply_environment}, "For puppet script") do
      # Merge in the facts.
      node.merge(facts.values) if facts

      # Add server facts so $server_facts[environment] exists when doing a puppet script
      # SCRIPT TODO: May be needed when running scripts under orchestrator. Leave it for now.
      #
      node.add_server_facts({})

      begin
        # Compile the catalog

        # When compiling, the compiler traps and logs certain errors
        # Those that do not lead to an immediate exit are caught by the general
        # rule and gets logged.
        #
        begin
          # support the following features when evaluating puppet code
          # * $facts with facts from host running the script
          # * $settings with 'settings::*' namespace populated, and '$settings::all_local' hash
          # * $trusted as setup when using puppet apply
          # * an environment
          #

          # fixup trusted information
          node.sanitize()

          compiler = Puppet::Parser::ScriptCompiler.new(node.environment, node.name)
          topscope = compiler.topscope

          # When scripting the trusted data are always local, but set them anyway
          topscope.set_trusted(node.trusted_data)

          # Server facts are always about the local node's version etc.
          topscope.set_server_facts(node.server_facts)

          # Set $facts for the node running the script
          facts_hash = node.facts.nil? ? {} : node.facts.values
          topscope.set_facts(facts_hash)

          # create the $settings:: variables
          topscope.merge_settings(node.environment.name, false)

          compiler.compile()

        rescue Puppet::Error
          # already logged and handled by the compiler, including Puppet::ParseErrorWithIssue
          exit(1)
        end

        exit(0)
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

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    handle_logdest_arg(Puppet[:logdest])
    Puppet::Util::Log.newdestination(:console) unless options[:setdest]

    Signal.trap(:INT) do
      $stderr.puts _("Exiting")
      exit(1)
    end

    # TODO: This skips applying the settings catalog for these settings, but
    # the effect of doing this is unknown. It may be that it only works if there is a puppet
    # installed where a settings catalog have already been applied...
    # This saves 1/5th of the startup time

#    Puppet.settings.use :main, :agent, :ssl

    # When running a script, the catalog is not relevant, and neither is caching of it
    Puppet::Resource::Catalog.indirection.cache_class = nil

    # we do not want the last report to be persisted
    Puppet::Transaction::Report.indirection.cache_class = nil

    set_log_level

    if Puppet[:profile]
      @profiler = Puppet::Util::Profiler.add_profiler(Puppet::Util::Profiler::Aggregate.new(Puppet.method(:info), "script"))
    end
  end
end
