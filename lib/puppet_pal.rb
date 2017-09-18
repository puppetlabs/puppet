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
    assert_non_empty_string(manifest_file, _("manifest file"))
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
    # TRANSLATORS: do not translate variable name string in these assertions
    assert_mutually_exclusive(manifest_file, code_string, 'manifest_file', 'code_string')
    assert_non_empty_string(manifest_file, 'manifest_file', true)
    assert_non_empty_string(code_string, 'code_string', true) 

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
  # @param modulepath [Array<String>] an array of directory paths containing Puppet modules, may be empty, defaults to empty array
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
    assert_non_empty_string(env_name, _("temporary environment name"))
    # TRANSLATORS: do not translate variable name string in these assertions
    assert_optionally_empty_array(modulepath, 'modulepath')

    unless block_given?
      raise ArgumentError, _("A block must be given to 'in_tmp_environment'") # TRANSLATORS 'in_tmp_environment' is a name, do not translate
    end

    env = Puppet::Node::Environment.create(env_name, modulepath)
    node = Puppet::Node.new(Puppet[:node_name_value], :environment => env)

    Puppet.override(
      environments: Puppet::Environments::Static.new(env), # The tmp env is the only known env
      current_node: node                                   # to allow it to be picked up instead of created
      ) do
      prepare_node_facts(node, facts)
      return yield self
    end
  end

  # Defines the context in which to perform puppet operations (evaluation, etc)
  # The code to evaluate in this context is given in a block.
  #
  # The name of an environment (env_name) is always given. The location of that environment on disk
  # is then either constructed by:
  # * searching a given envpath where name is a child of a directory on that path, or
  # * it is the directory given in env_dir (which must exist).
  # 
  # The env_dir and envpath options are mutually exclusive.
  #
  # @param env_name [String] the name of an existing environment
  # @param modulepath [Array<String>] an array of directory paths containing Puppet modules, overrides the modulepath of an existing env.
  #   Defaults to `{env_dir}/modules` if `env_dir` is given,
  # @param settings_hash [Hash] a hash of settings - currently not used for anything, defaults to empty hash
  # @param env_dir [String] a reference to a directory being the named environment (mutually exclusive with `envpath`)
  # @param envpath [String] a path of directories in which there are environments to search for `env_name` (mutually exclusive with `env_dir`)
  # @param facts [Hash] optional map of fact name to fact value - if not given will initialize the facts (which is a slow operation)
  # @return [Object] returns what the given block returns
  # @yieldparam [Puppet::Pal] context, a context that responds to Puppet::Pal methods
  #
  def self.in_environment(env_name,
      modulepath:    nil,
      settings_hash: {},
      env_dir:       nil,
      envpath:      nil,
      facts: nil
    )
    # TRANSLATORS terms in the assertions below are names of terms in code
    assert_non_empty_string(env_name, 'env_name')
    assert_optionally_empty_array(modulepath, 'modulepath', true) 
    assert_mutually_exclusive(env_dir, envpath, 'env_dir', 'envpath')

    unless block_given?
      raise ArgumentError, _("A block must be given to 'in_environment'") # TRANSLATORS 'in_environment' is a name, do not translate
    end

    if env_dir
      unless Puppet::FileSystem.exist?(env_dir)
        raise ArgumentError, _("The environment directory '%{env_dir}' does not exist") % { env_dir: env_dir }
      end

      # a nil modulepath for env_dir means it should use its ./modules directory
      if modulepath.nil?
        modulepath = [Puppet::FileSystem.expand_path(File.join(env_dir, 'modules'))]
      end
      env = Puppet::Node::Environment.create(env_name, modulepath)
      node = Puppet::Node.new(Puppet[:node_name_value], :environment => env)
      environments = Puppet::Environments::StaticDirectory.new(env_name, env_dir, env) # The env being used is the only one...
    else
      # The environment is resolved against the envpath. This is setup without a basemodulepath
      # The modulepath defaults to the 'modulepath' in the found env when "Directories" is used
      #
      environments = Puppet::Environments::Directories.new(envpath, [])
      env = environments.get(env_name)
      if env.nil?
        raise ArgumentError, _("No directory found for the environment '%{env_name}' on the path '%{envpath}'") % { env_name: env_name, envpath: envpath }
      end
      # A given modulepath should override the default
      env = env.override_with(:modulepath => modulepath) if !modulepath.nil?
      node = Puppet::Node.new(Puppet[:node_name_value], :environment => env)
    end
    Puppet.override(
      environments: environments,        # The env being used is the only one...
      current_node: node                 # to allow it to be picked up instead of created
      ) do
      prepare_node_facts(node, facts)
      return yield self
    end
  end

  private

  # Prepares the node for use by giving it node_facts (if given)
  # If a hash of facts values is given, then the operation of creating a node with facts is much
  # speeded up (as getting a fresh set of facts is avoided in a later step).
  #
  def self.prepare_node_facts(node, facts)
    # Prepare the node with facts if it does not already have them
    if node.facts.nil?
      node_facts = facts.nil? ? nil : Puppet::Node::Facts.new(Puppet[:node_name_value], facts)
      node.fact_merge(node_facts)
      # Add server facts so $server_facts[environment] exists when doing a puppet script
      # SCRIPT TODO: May be needed when running scripts under orchestrator. Leave it for now.
      #
      node.add_server_facts({})
    end
  end

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
          raise
      end
    end
  end

  T_STRING = Puppet::Pops::Types::PStringType::NON_EMPTY
  T_STRING_ARRAY = Puppet::Pops::Types::TypeFactory.array_of(T_STRING)

  def self.assert_type(type, value, what, allow_nil=false)
    Puppet::Pops::Types::TypeAsserter.assert_instance_of(nil, type, value, allow_nil) { _('Puppet Pal: %{what}') % {what: what} }
  end

  def self.assert_non_empty_string(s, what, allow_nil=false)
    assert_type(T_STRING, s, what, allow_nil)
  end

  def self.assert_optionally_empty_array(a, what, allow_nil=false)
    assert_type(T_STRING_ARRAY, a, what, allow_nil)
  end

  def self.assert_mutually_exclusive(a, b, a_term, b_term)
    if a && b
      raise ArgumentError, _("Cannot use '%{a_term}' and '%{b_term}' at the same time") % { a_term: a_term, b_term: b_term }
    end
  end

end
