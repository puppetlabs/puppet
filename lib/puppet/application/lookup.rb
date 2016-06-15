require 'puppet/application'
require 'puppet/pops'
require 'puppet/node'
require 'puppet/parser/compiler'

class Puppet::Application::Lookup < Puppet::Application

  RUN_HELP = "Run 'puppet lookup --help' for more details".freeze
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
      raise "The --fact file only accepts yaml and json files.\n#{RUN_HELP}"
    end
  end

  # Sets up the 'node_cache_terminus' default to use the Write Only Yaml terminus :write_only_yaml.
  # If this is not wanted, the setting ´node_cache_terminus´ should be set to nil.
  # @see Puppet::Node::WriteOnlyYaml
  # @see #setup_node_cache
  # @see puppet issue 16753
  #
  def app_defaults
    super.merge({
      :node_cache_terminus => :write_only_yaml,
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

  def help
    <<-'HELP'

puppet-lookup(8) -- Data in modules lookup function
========

SYNOPSIS
--------
The lookup command is used for debugging and testing a given data
configuration. For a given data key, lookup will produce either a
value or an explanation of how that value was obtained on the standard
output stream with the specified rendering format. Lookup is designed
to be run on a puppet master or a node in a masterless setup.

USAGE
-----
puppet lookup [--help] [--type <TYPESTRING>] [--merge unique|hash|deep]
  [--knock-out-prefix <PREFIX-STRING>] [--sort-merged-arrays]
  [--merge-hash-arrays] [--explain]
  [--default <VALUE>] [--node <NODE-NAME>] [--facts <FILE>]
  [--compile]
  [--render-as s|json|yaml|binary|msgpack] <keys>

DESCRIPTION
-----------
The lookup command is a CLI interface for the puppet lookup function.
When given one or more keys, the lookup command will return the first
value found when run from the puppet master or a masterless node.

When an explanation has not been requested and
lookup is simply looking up a value, the application will exit with 0
if a value was found and 1 otherwise. When an explanation is requested,
lookup will always exit with 0 unless there is a major error.

The other options are as passed into the lookup function, and the effect
they have on the lookup is described in more detail in the header
for the lookup function:

http://links.puppetlabs.com/lookup-docs

OPTIONS
-------
These options and their effects are described in more detail in
the puppet lookup function linked to above.

* --help:
  Print this help message.

* --type <TYPESTRING>:
  Assert that the value has the specified type.

* --merge unique|hash|deep:
  Specify the merge strategy. 'hash' performs a simple hash-merge by
  overwriting keys of lower lookup priority. 'unique' appends everything
  to an array containing no nested arrays and where all duplicates have been
  removed. 'deep' Performs a deep merge on values of Array and Hash type. There
  are additional option flags that can be used with 'deep'.

* --knock-out-prefix <PREFIX-STRING>
  Can be used with the 'deep' merge strategy. Specify string value to signify
  prefix which deletes elements from existing element.

* --sort-merged-arrays
  Can be used with the 'deep' merge strategy. When this flag is used all
  merged arrays will be sorted.

* --merge-hash-arrays
  Can be used with the 'deep' merge strategy. When this flag is used arrays
  and hashes will be merged.

* --explain
  Print an explanation for the details of how the lookup performed rather
  than the value returned for the key. The explanation will describe how
  the result was obtained or why lookup failed to obtain the result.

* --explain-options
  Explain if a lookup_options hash will be used and how it was assembled
  when performing a lookup.

* --default <VALUE>
  A value produced if no value was found in the lookup.

* --node <NODE-NAME>
  Specify node which defines the scope in which the lookup will be performed.
  If a node is not given, lookup will default to the machine from which the
  lookup is being run (which should be the master).

* --facts <FILE>
  Specify a .json, or .yaml file holding key => value mappings that will
  override the facts for the current node. Any facts not specified by the
  user will maintain their original value.

* --compile
  Perform a full catalog compilation prior to the lookup. This is meaningful when
  the catalog changes global variables that are referenced in interpolated values.
  No catalog compilation takes place unless this flag is given.

* --render-as s|json|yaml|binary|msgpack
  Determines how the results will be rendered to the standard output where
  s means plain text. The default when lookup is producing a value is yaml
  and the default when producing an explanation is s.

EXAMPLE
-------
  If you wanted to lookup 'key_name' within the scope of the master, you would
  call lookup like this:
  $ puppet lookup key_name

  If you wanted to lookup 'key_name' within the scope of the agent.local node,
  you would call lookup like this:
  $ puppet lookup --node agent.local key_name

  If you wanted to get the first value found for 'key_name_one' and 'key_name_two'
  within the scope of the agent.local node while merging values and knocking out
  the prefix 'foo' while merging, you would call lookup like this:
  $ puppet lookup --node agent.local --merge deep --knock-out-prefix foo key_name_one key_name_two

  If you wanted to lookup 'key_name' within the scope of the agent.local node,
  and return a default value of 'bar' if nothing was found, you would call
  lookup like this:
  $ puppet lookup --node agent.local --default bar key_name

  If you wanted to see an explanation of how the value for 'key_name' would be
  obtained in the context of the agent.local node, you would call lookup like this:
  $ puppet lookup --node agent.local --explain key_name

COPYRIGHT
---------
Copyright (c) 2015 Puppet Labs, LLC Licensed under the Apache 2.0 License


    HELP
  end

  def main
    keys = command_line.args

    #unless options[:node]
    #  raise "No node was given via the '--node' flag for the scope of the lookup.\n#{RUN_HELP}"
    #end

    if (options[:sort_merge_arrays] || options[:merge_hash_arrays] || options[:prefix]) && options[:merge] != 'deep'
      raise "The options #{DEEP_MERGE_OPTIONS} are only available with '--merge deep'\n#{RUN_HELP}"
    end

    use_default_value = !options[:default_value].nil?
    merge_options = nil

    merge = options[:merge]
    unless merge.nil?
      strategies = Puppet::Pops::MergeStrategy.strategy_keys
      unless strategies.include?(merge.to_sym)
        strategies = strategies.map {|k| "'#{k}'"}
        raise "The --merge option only accepts #{strategies[0...-1].join(', ')}, or #{strategies.last}\n#{RUN_HELP}"
      end

      if merge == 'deep'
        merge_options = {'strategy' => 'deep',
          'sort_merge_arrays' => !options[:sort_merge_arrays].nil?,
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
        raise 'No keys were given to lookup.'
      end
    end
    explain = explain_data || explain_options

    # Format defaults to text (:s) when producing an explanation and :yaml when producing the value
    format = options[:render_as] || (explain ? :s : :yaml)
    renderer = Puppet::Network::FormatHandler.format(format == :json ? :pson : format)
    raise "Unknown rendering format '#{format}'" if renderer.nil?


    generate_scope do |scope|
      lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, explain ? Puppet::Pops::Lookup::Explainer.new(explain_options, only_explain_options) : nil)
      begin
        type = options.include?(:type) ? Puppet::Pops::Types::TypeParser.singleton.parse(options[:type], scope) : nil
        result = Puppet::Pops::Lookup.lookup(keys, type, options[:default_value], use_default_value, merge_options, lookup_invocation)
        puts renderer.render(result) unless explain
      rescue Puppet::DataBinding::LookupError
        exit(1) unless explain
      end
      puts format == :s ? lookup_invocation.explainer.to_s : renderer.render(lookup_invocation.explainer.to_hash) if explain
    end
  end

  def generate_scope
    if options[:node]
      node = options[:node]
    else
      node = Puppet[:node_name_value]

      # If we want to lookup the node we are currently on
      # we must returning these settings to their default values
      Puppet.settings[:facts_terminus] = 'facter'
      Puppet.settings[:node_cache_terminus] = nil
    end

    node = Puppet::Node.indirection.find(node) unless node.is_a?(Puppet::Node) # to allow unit tests to pass a node instance

    fact_file = options[:fact_file]

    if fact_file
      original_facts = node.parameters
      if fact_file.end_with?("json")
        given_facts = JSON.parse(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      else
        given_facts = YAML.load(Puppet::FileSystem.read(fact_file, :encoding => 'utf-8'))
      end

      unless given_facts.instance_of?(Hash)
        raise "Incorrect formatted data in #{fact_file} given via the --facts flag"
      end

      node.parameters = original_facts.merge(given_facts)
    end

    Puppet[:code] = 'undef' unless options[:compile]
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.compile { |catalog| yield(compiler.topscope); catalog }
  end
end
