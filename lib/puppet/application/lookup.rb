require 'puppet/application'
require 'puppet/pops/lookup'
require 'puppet/node'
require 'puppet/parser/compiler'

class Puppet::Application::Lookup < Puppet::Application

  RUNHELP = "Run 'puppet lookup --help' for more details".freeze
  DEEP_MERGE_OPTIONS = "--knock_out_prefix, --sort_merged_arrays, --unpack_arrays, and --merge_hash_arrays".freeze

  # Options for lookup
  option('--merge TYPE') do |arg|
    if %w{unique hash deep}.include?(arg)
      options[:merge] = arg
    else
      raise "The --merge option only accepts 'unique', 'hash', or 'deep' as arguments.\n#{RUNHELP}"
    end
  end

  option('--type TYPE_STRING') do |arg|
    options[:type] = arg
  end

  option('--knock_out_prefix PREFIX_STRING') do |arg|
    options[:prefix] = arg
  end

  option('--sort_merge_arrays')

  option('--unpack_arrays') do |arg|
    options[:unpack_arrays] = arg
  end

  option('--merge_hash_arrays')

  # not yet supported
  option('--explain')

  option('--default VALUE') do |arg|
    options[:default_value] = arg
  end

  # not yet supported
  option('--trusted')

  # Options for facts/scope
  option('--node NODE_NAME') do |arg|
    options[:node] = arg
  end

  # not yet supported
  option('--facts FACT_FILE') do |arg|
    if %w{.yaml .yml .json}.include?(arg.match(/\.[^.]*$/)[0])
      options[:fact_file] = arg
    else
      raise "The --fact file only accepts yaml and json files as arguments.\n#{RUNHELP}"
    end
  end

  def run_command
    options[:keys] = command_line.args

    if options[:keys].empty?
     raise "No keys were given to lookup."
    end

    if !options[:node]
      raise "No node was given via the '--node' flag for the scope of the lookup."
    end

    if (options[:sort_merge_arrays] || options[:merge_hash_arrays] || options[:prefix] || options[:unpack_arrays]) && options[:merge] != 'deep'
      raise "The options #{DEEP_MERGE_OPTIONS} are only available with '--merge deep'\n#{RUNHELP}"
    end

    scope = generate_scope

    use_default_value = !options[:default_value].nil?
    merge_options = nil

    if options[:merge]
      if options[:merge] == 'deep'
        merge_options = {'strategy' => 'deep',
          'sort_merge_arrays' => !options[:sort_merge_arrays].nil?,
          'merge_hash_arrays' => !options[:merge_hash_arrays].nil?}

        if options[:prefix]
          merge_options.merge({'prefix' => options[:prefix]})
        end

        if options[:unpack_arrays]
          merge_options.merge({'unpack_arrays' => options[:unpack_arrays]})
        end

      else
        merge_options = {'strategy' => options[:merge]}
      end
    end

    puts Puppet::Pops::Lookup.lookup(scope, options[:keys], options[:type], options[:default_value], use_default_value, {}, {}, merge_options)
  end

  def generate_scope
    node = Puppet::Node.indirection.find("#{options[:node]}")
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.compile
    compiler.topscope
  end
end
