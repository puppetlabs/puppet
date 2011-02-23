require 'puppet/interface'

Puppet::Interface.new(:config) do
  action(:print) do |*args|
    if name
      Puppet.settings[:configprint] = args.join(",")
    end
    Puppet.settings.print_config_options
  end
end
