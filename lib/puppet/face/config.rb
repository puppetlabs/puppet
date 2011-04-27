require 'puppet/face'

Puppet::Face.define(:config, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Interact with Puppet configuration options"

  action(:print) do
    summary "Examine Puppet's current configuration options"
    description <<-EOT
Prints the value of a single configuration option or a list of
configuration options.

This action is an alternate interface to the information available with
`puppet agent --configprint`.
    EOT
    notes <<-EOT
The return data of this action varies depending on its arguments. When
called with "all," `print` will return a complete list of option names
and values. When called with a single configuration option name, it will
return the value of that option. When called with a list of
configuration option names, it will return the corresponding list of
option names and values.

By default, this action retrieves its configuration information in agent
mode. To examine the master's configuration, supply Puppet's global
`--mode master` option. To examine configurations from a specific
environment, you can use the `--environment` option.
    EOT
    examples <<-EOT
Get puppet's runfile directory:

    puppet config print rundir

Get a list of important directories from the master's config:

    puppet config print all --mode master | grep -E "(path|dir)"
    EOT

    when_invoked do |*args|
      options = args.pop
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
      nil
    end
  end
end
