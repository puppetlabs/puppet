require 'puppet/face'

Puppet::Face.define(:config, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with Puppet's configuration options."

  action(:print) do
    summary "Examine Puppet's current configuration settings."
    arguments "(all | <setting> [<setting> ...]"
    returns <<-'EOT'
      A single value when called with one config setting, and a list of
      settings and values when called with multiple options or "all."
    EOT
    description <<-'EOT'
      Prints the value of a single configuration option or a list of
      configuration options.

      This action is an alternate interface to the information available with
      `puppet <subcommand> --configprint`.
    EOT
    notes <<-'EOT'
      By default, this action reads the configuration in agent mode.
      Use the '--mode' and '--environment' flags to examine other
      configuration domains.
    EOT
    examples <<-'EOT'
      Get puppet's runfile directory:

      $ puppet config print rundir

      Get a list of important directories from the master's config:

      $ puppet config print all --mode master | grep -E "(path|dir)"
    EOT

    when_invoked do |*args|
      options = args.pop
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
      nil
    end
  end
end
