require 'puppet/application'
require 'puppet/pops'
require 'puppet/node'
require 'puppet/parser/compiler'

class Puppet::Application::Lookup < Puppet::Application

  RUN_HELP = _("Run 'puppet lookup --help' for more details").freeze
  DEEP_MERGE_OPTIONS = '--knock-out-prefix, --sort-merged-arrays, and --merge-hash-arrays'.freeze

  run_mode :master

  # Options for lookup
  option('--merge TYPE') do |arg|
    options[:merge] = arg
  end

  option('--debug', '-d')

  option('--verbose', '-v')

  option('--render-as FORMAT') do |format|
    options[:render_as] = format.downcase.to_sym
  end

  option('--type TYPE_STRING') do |arg|
    options[:type] = arg
  end

  option('--compile', '-c')

  option('--knock-out-prefix PREFIX_STRING') do |arg|
    options[:prefix] = arg
  end

  option('--sort-merge-arrays')

  option('--merge-hash-arrays')

  option('--explain')

  option('--explain-options')

  option('--default VALUE') do |arg|
    options[:default_value] = arg
  end

  # not yet supported
  option('--trusted')

  # Options for facts/scope
  option('--node NODE_NAME') do |arg|
    options[:node] = arg
  end

  option('--facts FACT_FILE') do |arg|
    if %w{.yaml .yml .json}.include?(arg.match(/\.[^.]*$/)[0])
      options[:fact_file] = arg
    else
      raise _("The --fact file only accepts yaml and json files.\n%{run_help}") % { run_help: RUN_HELP }
    end
  end

  def app_defaults
    super.merge({
      :facts_terminus => 'yaml'
    })
  end

  def setup_logs
    # This sets up logging based on --debug or --verbose if they are set in `options`
    set_log_level

    # This uses console for everything that is not a compilation
    Puppet::Util::Log.newdestination(:console)
  end

  def setup_terminuses
    require 'puppet/file_serving/content'
    require 'puppet/file_serving/metadata'

    Puppet::FileServing::Content.indirection.terminus_class = :file_server
    Puppet::FileServing::Metadata.indirection.terminus_class = :file_server

    Puppet::FileBucket::File.indirection.terminus_class = :file
  end

  def setup
    setup_logs

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet.settings.use :main, :master, :ssl, :metrics

    setup_terminuses
  end

  def summary
    _("Interactive Hiera lookup")
  end

  def help
    <<-HELP

puppet-lookup(8) -- #{summary}
========

SYNOPSIS
--------
Does Hiera lookups from the command line.

Since this command needs access to your Hiera data, make sure to run it on a
node that has a copy of that data. This usually means logging into a Puppet
Server node and running 'puppet lookup' with sudo.

The most common version of this command is:

'puppet lookup <KEY> --node <NAME> --environment <ENV> --explain'

USAGE
-----
puppet lookup [--help] [--type <TYPESTRING>] [--merge first|unique|hash|deep]
  [--knock-out-prefix <PREFIX-STRING>] [--sort-merged-arrays]
  [--merge-hash-arrays] [--explain] [--environment <ENV>]
  [--default <VALUE>] [--node <NODE-NAME>] [--facts <FILE>]
  [--compile]
  [--render-as s|json|yaml|binary|msgpack] <keys>

DESCRIPTION
-----------
The lookup command is a CLI for Puppet's 'lookup()' function. It searches your
Hiera data and returns a value for the requested lookup key, so you can test and
explore your data. It is a modern replacement for the 'hiera' command.

Hiera usually relies on a node's facts to locate the relevant data sources. By
default, 'puppet lookup' uses facts from the node you run the command on, but
you can get data for any other node with the '--node <NAME>' option. If
possible, the lookup command will use the requested node's real stored facts
from PuppetDB; if PuppetDB isn't configured or you want to provide arbitrary
fact values, you can pass alternate facts as a JSON or YAML file with '--facts
<FILE>'.

If you're debugging your Hiera data and want to see where values are coming
from, use the '--explain' option.

If '--explain' isn't specified, lookup exits with 0 if a value was found and 1
otherwise. With '--explain', lookup always exits with 0 unless there is a major
error.

You can provide multiple lookup keys to this command, but it only returns a
value for the first found key, omitting the rest.

For more details about how Hiera works, see the Hiera documentation:
https://docs.puppet.com/puppet/latest/hiera_intro.html

OPTIONS
-------

* --help:
  Print this help message.

* --explain
  Explain the details of how the lookup was performed and where the final value
  came from (or the reason no value was found).

* --node <NODE-NAME>
  Specify which node to look up data for; defaults to the node where the command
  is run. Since Hiera's purpose is to provide different values for different
  nodes (usually based on their facts), you'll usually want to use some specific
  node's facts to explore your data. If the node where you're running this
  command is configured to talk to PuppetDB, the command will use the requested
  node's most recent facts. Otherwise, you can override facts with the '--facts'
  option.

* --facts <FILE>
  Specify a .json or .yaml file of key => value mappings to override the facts
  for this lookup. Any facts not specified in this file maintain their
  original value.

* --environment <ENV>
  Like with most Puppet commands, you can specify an environment on the command
  line. This is important for lookup because different environments can have
  different Hiera data.

* --merge first|unique|hash|deep:
  Specify the merge behavior, overriding any merge behavior from the data's
  lookup_options. 'first' returns the first value found. 'unique' appends
  everything to a merged, deduplicated array. 'hash' performs a simple hash
  merge by overwriting keys of lower lookup priority. 'deep' performs a deep
  merge on values of Array and Hash type. There are additional options that can
  be used with 'deep'.

* --knock-out-prefix <PREFIX-STRING>
  Can be used with the 'deep' merge strategy. Specifies a prefix to indicate a
  value should be removed from the final result.

* --sort-merged-arrays
  Can be used with the 'deep' merge strategy. When this flag is used, all
  merged arrays are sorted.

* --merge-hash-arrays
  Can be used with the 'deep' merge strategy. When this flag is used, hashes
  WITHIN arrays are deep-merged with their counterparts by position.

* --explain-options
  Explain whether a lookup_options hash affects this lookup, and how that hash
  was assembled. (lookup_options is how Hiera configures merge behavior in data.)

* --default <VALUE>
  A value to return if Hiera can't find a value in data. For emulating calls to
  the 'lookup()' function that include a default.

* --type <TYPESTRING>:
  Assert that the value has the specified type. For emulating calls to the
  'lookup()' function that include a data type.

* --compile
  Perform a full catalog compilation prior to the lookup. If your hierarchy and
  data only use the $facts, $trusted, and $server_facts variables, you don't
  need this option; however, if your Hiera configuration uses arbitrary
  variables set by a Puppet manifest, you might need this option to get accurate
  data. No catalog compilation takes place unless this flag is given.

* --render-as s|json|yaml|binary|msgpack
  Specify the output format of the results; "s" means plain text. The default
  when producing a value is yaml and the default when producing an explanation
  is s.

EXAMPLE
-------
  To look up 'key_name' using the Puppet Server node's facts:
  $ puppet lookup key_name

  To look up 'key_name' with agent.local's facts:
  $ puppet lookup --node agent.local key_name

  To get the first value found for 'key_name_one' and 'key_name_two'
  with agent.local's facts while merging values and knocking out
  the prefix 'foo' while merging:
  $ puppet lookup --node agent.local --merge deep --knock-out-prefix foo key_name_one key_name_two

  To lookup 'key_name' with agent.local's facts, and return a default value of
  'bar' if nothing was found:
  $ puppet lookup --node agent.local --default bar key_name

  To see an explanation of how the value for 'key_name' would be found, using
  agent.local's facts:
  $ puppet lookup --node agent.local --explain key_name

COPYRIGHT
---------
Copyright (c) 2015 Puppet Inc., LLC Licensed under the Apache 2.0 License


    HELP
  end

  def main
    keys = command_line.args

    #unless options[:node]
    #  raise "No node was given via the '--node' flag for the scope of the lookup.\n#{RUN_HELP}"
    #end

    if (options[:sort_merged_arrays] || options[:merge_hash_arrays] || options[:prefix]) && options[:merge] != 'deep'
      raise _("The options %{deep_merge_opts} are only available with '--merge deep'\n%{run_help}") % { deep_merge_opts: DEEP_MERGE_OPTIONS, run_help: RUN_HELP }
    end

    use_default_value = !options[:default_value].nil?
    merge_options = nil

    merge = options[:merge]
    unless merge.nil?
      strategies = Puppet::Pops::MergeStrategy.strategy_keys
      unless strategies.include?(merge.to_sym)
        strategies = strategies.map {|k| "'#{k}'"}
        raise _("The --merge option only accepts %{strategies}, or %{last_strategy}\n%{run_help}") % { strategies: strategies[0...-1].join(', '), last_strategy: strategies.last, run_help: RUN_HELP }
      end

      if merge == 'deep'
        merge_options = {'strategy' => 'deep',
          'sort_merged_arrays' => !options[:sort_merged_arrays].nil?,
          'merge_hash_arrays' => !options[:merge_hash_arrays].nil?}

        if options[:prefix]
          merge_options.merge!({'knockout_prefix' => options[:prefix]})
        end

      else
        merge_options = {'strategy' => merge}
      end
    end

    explain_data = !!options[:explain]
    explain_options = !!options[:explain_options]
    only_explain_options = explain_options && !explain_data
    if keys.empty?
      if only_explain_options
        # Explain lookup_options for lookup of an unqualified value.
        keys = Puppet::Pops::Lookup::GLOBAL
      else
        raise _('No keys were given to lookup.')
      end
    end
    explain = explain_data || explain_options

    # Format defaults to text (:s) when producing an explanation and :yaml when producing the value
    format = options[:render_as] || (explain ? :s : :yaml)
    renderer = Puppet::Network::FormatHandler.format(format)
    raise _("Unknown rendering format '%{format}'") % { format: format } if renderer.nil?

    generate_scope do |scope|
      lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, explain ? Puppet::Pops::Lookup::Explainer.new(explain_options, only_explain_options) : nil)
      begin
        type = options.include?(:type) ? Puppet::Pops::Types::TypeParser.singleton.parse(options[:type], scope) : nil
        result = Puppet::Pops::Lookup.lookup(keys, type, options[:default_value], use_default_value, merge_options, lookup_invocation)
        puts renderer.render(result) unless explain
      rescue Puppet::DataBinding::LookupError => e
        lookup_invocation.report_text { e.message }
        exit(1) unless explain
      end
      puts format == :s ? lookup_invocation.explainer.explain : renderer.render(lookup_invocation.explainer.to_hash) if explain
    end
    exit(0)
  end

  def generate_scope
    if options[:node]
      node = options[:node]
    else
      node = Puppet[:node_name_value]

      # If we want to lookup the node we are currently on
      # we must returning these settings to their default values
      Puppet.settings[:facts_terminus] = 'facter'
    end

    unless node.is_a?(Puppet::Node) # to allow unit tests to pass a node instance
      ni = Puppet::Node.indirection
      tc = ni.terminus_class
      if tc == :plain || options[:compile]
        node = ni.find(node)
      else
        ni.terminus_class = :plain
        node = ni.find(node)
        ni.terminus_class = tc
      end
    end

    fact_file = options[:fact_file]

    if fact_file
      if fact_file.end_with?("json")
        given_facts = Puppet::Util::Json.load(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      else
        given_facts = YAML.load(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      end

      unless given_facts.instance_of?(Hash)
        raise _("Incorrect formatted data in %{fact_file} given via the --facts flag") % { fact_file: fact_file }
      end
      node.add_extra_facts(given_facts)
    end

    Puppet[:code] = 'undef' unless options[:compile]
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.compile { |catalog| yield(compiler.topscope); catalog }
  end
end
