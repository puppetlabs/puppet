require 'puppet/provider/naginator'

Puppet::Type.type(:nagios_command).provide(:naginator, :parent => Puppet::Provider::Naginator, :default_target => '/tmp/nagios/nagios_command.cfg') do
end
