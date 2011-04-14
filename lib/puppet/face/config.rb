require 'puppet/face'

Puppet::Face.define(:config, '0.0.1') do
  summary "Interact with Puppet configuration options."

  action(:print) do
    when_invoked do |*args|
      options = args.pop
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
      nil
    end
  end
end
