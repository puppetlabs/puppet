# Puppet as a Library "PAL"

# Yes, this requires all of puppet for now because 'settings' and many other things...
require 'puppet'
require 'puppet/parser/script_compiler'

# This is the main entry point for "Puppet As a Library" PAL.
# This file should be required instead of "puppet"
# Initially, this will require ALL of puppet - over time this will change as the monolithical "puppet" is broken up
# into smaller components.
#
# @Example Usage
#   require 'puppet_pal'
#   result = Puppet::Pal.in_tmp_environment('pal_env', modulepath) do
#     Puppet::Pal.evaluate_script_string('1+2+3')
#   end
#   # The result is the value 6
#
module Puppet::Pal

  def self.evaluate_script_string(code_string:)
    Puppet[:tasks] = true
    Puppet[:code] = code_string
    main
  end

  def self.evaluate_script_manifest(manifest_file:)
    Puppet[:tasks] = true
    main(manifest_file)
  end

  # Runs the given named plan passing arguments by name in the given hash.
  # @param plan_name [String] the name of the plan to run
  # @param plan_args [Hash] arguments to the plan - a map of plan parameter name to value
  #
  def self.run_plan(plan_name: , plan_args: {})
    Puppet[:tasks] = true
    main()
  end

  def self.main(manifest = nil, facts = nil)

    # Find the Node (TODO: This is slow when running many tests against the API
    # Need to find good method of speeding that up since the node facts will be the
    # same every time.
    #
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

    # TRANSLATION, the string "For puppet PAL" is not user facing
    Puppet.override({:current_environment => apply_environment}, "For puppet PAL") do
#      # Facts are always in the node we are running on, nothing to merge here
#      # Merge in the facts.
#      node.merge(facts.values) if facts
# keep this commented out as reminder that we may want to feed in facts for testing purposes


      # Add server facts so $server_facts[environment] exists when doing a puppet script
      # SCRIPT TODO: May be needed when running scripts under orchestrator. Leave it for now.
      #
      node.add_server_facts({})

      begin
        # Evaluate

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

# TODO: cannot exit here, for now only logging takes place and raised errors are propagated
#        rescue Puppet::ParseErrorWithIssue, Puppet::Error
#          # already logged and handled by the compiler for these two cases
#          exit(1)
        end
#
#        exit(0)
      rescue => detail
        Puppet.log_exception(detail)
        raise # exit(1)
      end
    end
  end

  def self.in_tmp_environment(env_name, modulepath, settings_hash ={})
    unless env_name.is_a?(String) && env_name.length > 0
      raise ArgumentError(_("Puppet Pal: temporary environment name must be a non empty string, got '%{env_name}'") % {:env_name => env_name})
    end

    unless modulepath.is_a?(Array)
      raise ArgumentError(_("Puppet Pal: modulepath must be an Array, got '%{type}'") % {:type => modulepath.class})
    end

    # tmp env with an optional empty modulepath - (may be empty if just running snippet of code)

    unless modulepath.is_a?(Array)
      raise ArgumentError(_("Puppet Pal: modulepath must be an Array (it may be empty)'"))
    end

    return unless block_given?

    env = Puppet::Node::Environment.create(env_name, modulepath)
    Puppet.override(environments: Puppet::Environments::Static.new(env)) do
      return yield
    end
  end

# TODO: Make it possible to run in an existing environment (pick up environment settings from there
# with modulepath etc.
#
#  def self.in_existing_environment(env_name, settings_hash)
#  end

end


