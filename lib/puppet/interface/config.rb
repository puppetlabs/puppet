require 'puppet/interface'

Puppet::Interface.interface(:config) do
  action(:print) do
    invoke do |*args|
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
    end
  end
end
