require 'puppet/network/format_handler'

Puppet::Network::FormatHandler.create(:yaml, :mime => "text/yaml")
Puppet::Network::FormatHandler.create(:marshal, :mime => "text/marshal")
