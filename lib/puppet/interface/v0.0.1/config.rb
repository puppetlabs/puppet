require 'puppet/interface'

Puppet::Interface.define(:config, '0.0.1') do
  action(:print) do
    invoke do |*args|
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
    end
  end
end
