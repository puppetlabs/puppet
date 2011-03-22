require 'puppet/interface'

Puppet::Interface.new(:config) do
  action(:print) do
    invoke do |*args|
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
    end
  end
end
