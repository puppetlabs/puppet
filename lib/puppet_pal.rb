# Puppet as a Library "PAL"

# Yes, this requires all of puppet for now because 'settings' and many other things...
require 'puppet'
require 'puppet/parser/script_compiler'

# This is the main entry point for "Puppet As a Library" PAL.
# This file should be required instead of "puppet"
# Initially, this will require ALL of puppet - over time this will change as the monolithical "puppet" is broken up
# into smaller components.
#
# @example Running a snippet of Puppet Language code
#   require 'puppet_pal'
#   result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: ['/tmp/testmodules']) do |pal|
#     pal.evaluate_script_string('1+2+3')
#   end
#   # The result is the value 6
#
# @example Making a run_plan call
#   require 'puppet_pal'
#   result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: ['/tmp/testmodules']) do |pal|
#     pal.run_plan('mymodule::myplan', plan_args: { 'arg1' => 10, 'arg2' => '20 })
#   end
#   # The result is what 'mymodule::myplan' returns
#
module Puppet::Pal

  # Evaluates a Puppet Language script string. 
  # @param code_string [String] a snippet of Puppet Language source code
  # @return [Object] what the Puppet Language code_string evaluates to
  #
  def self.evaluate_script_string(code_string)
    Puppet[:tasks] = true
    Puppet[:code] = code_string
    main
  end

  # Evaluates a Puppet Language script (.pp) file.
  # @param manifest_file [String] a file with Puppet Language source code
  # @return [Object] what the Puppet Language manifest_file contents evaluates to
  #
  def self.evaluate_script_manifest(manifest_file)
    Puppet[:tasks] = true
    main(manifest_file)
  end

  # Runs the given named plan passing arguments by name in a hash.
  # @param plan_name [String] the name of the plan to run
  # @param plan_args [Hash] arguments to the plan - a map of plan parameter name to value, defaults to empty hash
  # @param manifest_file [String] a Puppet Language file to load and evaluate before running the plan, mutually exclusive with code_string
  # @param code_string [String] a Puppet Language source string to load and evaluate before running the plan, mutually exclusive with manifest_file
  # @return [Object] returns what the evaluated plan returns
  #
  def self.run_plan(plan_name,
      plan_args:     {},
      manifest_file: nil,
      code_string:   nil
    )
    if manifest_file && code_string
      raise ArgumentError, _("Cannot use 'manifest' and 'code_string' at the same time")
    end

    unless manifest_file.nil? || manifest_file.is_a?(String)
      raise ArgumentError, _("Expected 'manifest_file' to be a String, got '%{type}") % { type: manifest_file.class }
    end

    unless code_string.nil? || code_string.is_a?(String)
      raise ArgumentError, _("Expected 'code_string' to be a String, got '%{type}") % { type: manifest_file.class }
    end

    Puppet[:tasks] = true
    Puppet[:code] = code_string unless code_string.nil?
    main(manifest_file) do | compiler |
      compiler.topscope.call_function('run_plan', [plan_name, plan_args])
    end
  end

  # Defines the context in which to perform puppet operations (evaluation, etc)
  # The code to evaluate in this context is given in a block.
  #
  # @param env_name [String] a name to use for the temporary environment - this only shows up in errors
  # @param modulepath [Array<String>] an array of directory names containing Puppet modules, may be empty, defaults to empty array
  # @param settings_hash [Hash] a hash of settings - currently not used for anything, defaults to empty hash
  # @param facts [Hash] optional map of fact name to fact value - if not given will initialize the facts (which is a slow operation)
  # @return [Object] returns what the given block returns
  # @yieldparam [Puppet::Pal] context, a context that responds to Puppet::Pal methods
  #
  def self.in_tmp_environment(env_name,
      modulepath:    [],
      settings_hash: {},
      facts: nil
    )
    unless env_name.is_a?(String) && env_name.length > 0
      raise ArgumentError(_("Puppet Pal: temporary environment name must be a non empty string, got '%{env_name}'") % {env_name: env_name})
    end

    unless modulepath.is_a?(Array)
      raise ArgumentError(_("Puppet Pal: modulepath must be an Array, got '%{type}'") % {type: modulepath.class})
    end

    # tmp env with an optional empty modulepath - (may be empty if just running snippet of code)

    unless modulepath.is_a?(Array)
      raise ArgumentError(_("Puppet Pal: modulepath must be an Array (it may be empty)'"))
    end

    return unless block_given?

    env = Puppet::Node::Environment.create(env_name, modulepath)
    node = Puppet::Node.new(Puppet[:node_name_value], :environment => env)

    Puppet.override(
      environments: Puppet::Environments::Static.new(env), # The tmp env is the only known env
      current_node: node                                   # to allow it to be picked up instead of created
      ) do
      # Prepare the node with facts if it does not already have them
      if node.facts.nil?
        # if a hash of facts values is given, then the operation of creating a node with facts is much
        # speeded up.
        #
        node_facts = facts.nil? ? nil : Puppet::Node::Facts.new(Puppet[:node_name_value], facts)
        node.fact_merge(node_facts)
        # Add server facts so $server_facts[environment] exists when doing a puppet script
        # SCRIPT TODO: May be needed when running scripts under orchestrator. Leave it for now.
        #
        node.add_server_facts({})
      end

      return yield self
    end
  end

  # TODO: Make it possible to run in an existing environment (pick up environment settings from there
  # with modulepath etc.
  #
  #  def self.in_existing_environment(env_name, settings_hash)
  #  end

  private

  def self.main(manifest = nil, facts = nil, &block)
    node = Puppet.lookup(:current_node)
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

    # TRANSLATORS, the string "For puppet PAL" is not user facing
    Puppet.override({:current_environment => apply_environment}, "For puppet PAL") do
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

          compiler.compile(&block)

        rescue Puppet::ParseErrorWithIssue, Puppet::Error => detail
          # already logged and handled by the compiler for these two cases
          raise

        rescue => detail
          Puppet.log_exception(detail)
          raise # exit(1)
      end
    end
  end
end