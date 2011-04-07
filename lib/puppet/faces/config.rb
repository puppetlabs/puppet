require 'puppet/faces'

Puppet::Faces.define(:config, '0.0.1') do
  action(:print) do
    when_invoked do |*args|
      options = args.pop
      Puppet.settings[:configprint] = args.join(",")
      Puppet.settings.print_config_options
      nil
    end
  end
end
