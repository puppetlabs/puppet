require 'puppet/string'

Puppet::String.define(:config, '0.0.1') do
  action(:print) do
    invoke do |*args|
      options = args.pop
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
      nil
    end
  end
end
